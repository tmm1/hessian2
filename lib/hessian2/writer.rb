require 'hessian2/constants'

module Hessian2
  module Writer
    include Constants

    def call(method, args)
      refs, crefs, trefs = {}, {}, {}
      out = [ 'H', '2', '0', 'C' ].pack('ahha')
      out << write_string(method)
      out << write_int(args.size)
      args.each { |arg| out << write(arg, refs, crefs, trefs) }
      out
    end

    def reply(val)
      [ 'H', '2', '0', 'R' ].pack('ahha') << write(val)
    end

    def write_fault(e)
      val = {
        code: e.class.to_s,
        message: e.message,
        detail: e.backtrace }
      [ 'F' ].pack('a') << write_hash(val)
    end

    def write(val, refs = {}, crefs = {}, trefs = {})
      case val
      when ClassWrapper # hash as monkey; monkey as example.monkey; [hash as [monkey; [monkey as [example.monkey
        idx = refs[val.object_id]
        return write_ref(idx) if idx

        obj = val.object
        return write_nil if obj.nil?
        refs[val.object_id] = refs.size # store a value reference

        if obj.class == Array 
          type = val.hessian_class
          if trefs.include?(type)
            tstr = write_int(trefs[type])
          else
            trefs[type] = trefs.size # store a type
            tstr = write_string(type)
          end

          return [ BC_LIST_DIRECT ].pack('C') << tstr if obj.size == 0
        end

        klass = val.hessian_class.delete('[]')
        cref = crefs[klass]
        if cref
          cidx = cref.first
          fields = cref.last
          str = ''
        else
          fields = []
          cref = crefs[klass] = [crefs.size, fields] # store a class definition
          cidx = cref.first
          fstr = ''
          if obj.class == Array
            sample = obj.first
            if sample.class == Hash
              fields = sample.keys
              fields.each do |f|
                fstr << write_string(f.to_s)
              end
            else
              fields = sample.instance_variables
              fields.each do |f|
                fstr << write_string(f.to_s[1..-1]) # skip '@'
              end
            end
          elsif obj.class == Hash
            fields = obj.keys
            fields.each do |f|
              fstr << write_string(f.to_s)
            end
          else
            fields = obj.instance_variables
            fields.each do |f|
              fstr << write_string(f.to_s[1..-1])
            end
          end

          str = [ BC_OBJECT_DEF ].pack('C') << write_string(klass) << write_int(fields.size) << fstr
        end

        if cidx <= OBJECT_DIRECT_MAX
          cstr = [ BC_OBJECT_DIRECT + cidx ].pack('C')
        else
          cstr = [ BC_OBJECT ].pack('C') << write_int(cidx)
        end

        if obj.class == Array
          str << write_class_wrapped_array(obj, tstr, cstr, fields, refs, crefs, trefs)
        elsif obj.class == Hash
          str << write_class_wrapped_hash(obj, cstr, fields, refs, crefs, trefs)
        else
          str << write_class_wrapped_object(obj, cstr, fields, refs, crefs, trefs)
        end

        str
      when TypeWrapper
        idx = refs[val.object_id]
        return write_ref(idx) if idx

        obj = val.object
        return write_nil if obj.nil?
        refs[val.object_id] = refs.size

        type = val.hessian_type
        if obj.class == Array 
          if trefs.include?(type)
            tstr = write_int(trefs[type])
          else
            trefs[type] = trefs.size
            tstr = write_string(type)
          end
          write_type_wrapped_array(obj, tstr, type.delete('[]'), refs, crefs, trefs)
        else
          case type
          when 'L', 'Long', 'long'
            write_long(Integer(obj))
          when 'I', 'Integer', 'int'
            write_int(Integer(obj))
          when 'B', 'b'
            write_binary(obj)
          else
            write_type_wrapped_hash(obj, tstr, refs, crefs, trefs)
          end
        end
      when TrueClass
        [ BC_TRUE ].pack('C')
      when FalseClass
        [ BC_FALSE ].pack('C')
      when Time
        if val.usec == 0 and val.sec == 0 # date in minutes
          [ BC_DATE_MINUTE, val.to_i / 60 ].pack('CL>')
        else
          [ BC_DATE, val.to_i * 1000 + val.usec / 1000 ].pack('CQ>') # date
        end
      when Float
        case val.infinite?
        when 1
          return [ BC_DOUBLE, Float::INFINITY ].pack('CG')
        when -1
          return [ BC_DOUBLE, -Float::INFINITY ].pack('CG')
        else
          return [ BC_DOUBLE, Float::NAN ].pack('CG') if val.nan?
          return [ BC_DOUBLE_ZERO ].pack('C') if val.zero? # double zero
          return [ BC_DOUBLE_ONE ].pack('C') if val == 1 # double one
          ival = val.to_i
          if ival == val
            return [ BC_DOUBLE_BYTE, ival ].pack('Cc') if (-0x80..0x7f).include?(ival) # double octet
            return [ BC_DOUBLE_SHORT, (ival >> 8), ival ].pack('Ccc') if (-0x8000..0x7fff).include?(ival) # double short
          end
          mval = val * 1000
          if mval.finite?
            mills = mval.to_i
            if (-0x80_000_000..0x7f_fff_fff).include?(mills) and 0.001 * mills == val
              [ BC_DOUBLE_MILL, mills ].pack('Cl>') # double mill
            end
          end
          [ BC_DOUBLE, val ].pack('CG') # double
        end
      when Fixnum
        write_int(val)
      when Array
        write_array(val, refs, crefs, trefs)
      when Bignum
        if (-0x80_000_000..0x7f_fff_fff).include?(val) # four octet longs
          [ BC_LONG_INT, val ].pack('Cl>')
        else # long
          [ BC_LONG, val ].pack('Cq>')
        end
      when Hash
        write_hash(val, refs, crefs, trefs)
      when NilClass
        write_nil
      when String
        write_string(val)
      when Symbol
        write_string(val.to_s)
      else
        write_object(val, refs, crefs, trefs)
      end
    end

    def print_string(str)
      arr, i = Array.new(str.bytesize), 0
      str.unpack('U*').each do |c|
        if c < 0x80 # 0xxxxxxx
          arr[i] = c
        elsif c < 0x800 # 110xxxxx 10xxxxxx
          arr[i] = 0xc0 + ((c >> 6) & 0x1f)
          arr[i += 1] = 0x80 + (c & 0x3f)
        else # 1110xxxx 10xxxxxx 10xxxxxx
          arr[i] = 0xe0 + ((c >> 12) & 0xf)
          arr[i += 1] = 0x80 + ((c >> 6) & 0x3f)
          arr[i += 1] = 0x80 + (c & 0x3f)
        end
        i += 1
      end
      arr.pack('C*')
    end

    def write_class_wrapped_array(arr, tstr, cstr, fields, refs = {}, crefs = {}, trefs = {})
      idx = refs[arr.object_id]
      return write_ref(idx) if idx
      refs[arr.object_id] = refs.size

      len = arr.size
      if len <= LIST_DIRECT_MAX # [x70-77] type value*
        str = [ BC_LIST_DIRECT + len ].pack('C') << tstr
      else  # 'V' type int value*
        str = [ BC_LIST_FIXED ].pack('C') << tstr << write_int(len)
      end

      if arr.first.class == Hash
        arr.each do |ele|
          idx = refs[ele.object_id]
          if idx
            str << write_ref(idx)
          else
            refs[ele.object_id] = refs.size
            str << cstr
            fields.each do |f|
              str << write(ele[f], refs, crefs, trefs)
            end
          end
        end
      else
        arr.each do |ele|
          idx = refs[ele.object_id]
          if idx
            str << write_ref(idx)
          else
            refs[ele.object_id] = refs.size
            str << cstr
            fields.each do |f|
              str << write(ele.instance_variable_get(f), refs, crefs, trefs)
            end
          end
        end
      end

      str
    end

    def write_type_wrapped_array(arr, tstr, eletype, refs = {}, crefs = {}, trefs = {})
      idx = refs[arr.object_id]
      return write_ref(idx) if idx
      refs[arr.object_id] = refs.size

      len = arr.size
      if len <= LIST_DIRECT_MAX # [x70-77] type value*
        str = [ BC_LIST_DIRECT + len ].pack('C') << tstr
      else  # 'V' type int value*
        str = [ BC_LIST_FIXED ].pack('C') << tstr << write_int(len)
      end

      case eletype
      when 'L', 'Long', 'long'
        arr.each do |ele|
          str << write_long(Integer(ele))
        end
      when 'I', 'Integer', 'int'
        arr.each do |ele|
          str << write_int(Integer(ele))
        end
      when 'B', 'b'
        arr.each do |ele|
          str << write_binary(ele)
        end
      else
        arr.each do |ele|
          str << write_type_wrapped_hash(ele, tstr, refs, crefs, trefs)
        end
      end
      
      str
    end

    def write_array(arr, refs = {}, crefs = {}, trefs = {})
      idx = refs[arr.object_id]
      return write_ref(idx) if idx
      refs[arr.object_id] = refs.size

      len = arr.size
      if len <= LIST_DIRECT_MAX # [x78-7f] value*
        str = [ BC_LIST_DIRECT_UNTYPED + len ].pack('C')
      else  # x58 int value*
        str = [ BC_LIST_FIXED_UNTYPED ].pack('C') << write_int(len)
      end
      arr.each do |ele|
        str << write(ele, refs, crefs, trefs)
      end

      str
    end

    def write_binary(str)
      chunks, i, len = [], 0, str.size
      while len > 0x8000
        chunks << [ BC_BINARY_CHUNK, 0x8000 ].pack('Cn') << str[i...(i += 0x8000)]
        len -= 0x8000
      end
      final = str[i..-1]
      if len <= BINARY_DIRECT_MAX
        chunks << [ BC_BINARY_DIRECT + len ].pack('C') << final
      elsif len <= BINARY_SHORT_MAX
        chunks << [ BC_BINARY_SHORT + (len >> 8), len ].pack('CC') << final
      else
        chunks << [ BC_BINARY, len ].pack('Cn') << final
      end
      chunks.join
    end

    def write_class_wrapped_hash(hash, cstr, fields, refs = {}, crefs = {}, trefs = {})
      idx = refs[hash.object_id]
      return write_ref(idx) if idx
      refs[hash.object_id] = refs.size

      str = cstr
      fields.each do |f|
        str << write(hash[f], refs, crefs, trefs)
      end

      str
    end

    def write_type_wrapped_hash(hash, tstr, refs = {}, crefs = {}, trefs = {})
      idx = refs[hash.object_id]
      return write_ref(idx) if idx
      refs[hash.object_id] = refs.size

      str = [ BC_MAP ].pack('C') << tstr
      hash.each do |k, v|
        str << write(k, refs, crefs, trefs)
        str << write(v, refs, crefs, trefs)
      end

      str << [ BC_END ].pack('C')
    end

    def write_hash(hash, refs = {}, crefs = {}, trefs = {})
      idx = refs[hash.object_id]
      return write_ref(idx) if idx
      refs[hash.object_id] = refs.size

      str = [ BC_MAP_UNTYPED ].pack('C')
      hash.each do |k, v|
        str << write(k, refs, crefs, trefs)
        str << write(v, refs, crefs, trefs)
      end

      str << [ BC_END ].pack('C')
    end

    def write_int(val)
      case val
      when INT_DIRECT_MIN..INT_DIRECT_MAX # single octet integers
        [ BC_INT_ZERO + val ].pack('c')
      when INT_BYTE_MIN..INT_BYTE_MAX # two octet integers
        [ BC_INT_BYTE_ZERO + (val >> 8), val ].pack('cc')
      when INT_SHORT_MIN..INT_SHORT_MAX # three octet integers
        [ BC_INT_SHORT_ZERO + (val >> 16), (val >> 8), val].pack('ccc')
      when -0x80_000_000..0x7f_fff_fff # integer
        [ BC_INT, val ].pack('Cl>')
      else
        [ BC_LONG, val ].pack('Cq>')
      end
    end

    def write_long(val)
      case val
      when LONG_DIRECT_MIN..LONG_DIRECT_MAX # single octet longs
        [ BC_LONG_ZERO + val ].pack('c')
      when LONG_BYTE_MIN..LONG_BYTE_MAX # two octet longs
        [ BC_LONG_BYTE_ZERO + (val >> 8), val ].pack('cc')
      when LONG_SHORT_MIN..LONG_SHORT_MAX # three octet longs
        [ BC_LONG_SHORT_ZERO + (val >> 16), (val >> 8), val ].pack('ccc')
      when -0x80_000_000..0x7f_fff_fff # four octet longs
        [ BC_LONG_INT, val ].pack('Cl>')
      else
        [ BC_LONG, val ].pack('Cq>')
      end
    end

    def write_nil
      [ BC_NULL ].pack('C')
    end

    def write_class_wrapped_object(obj, cstr, fields, refs = {}, crefs = {}, trefs = {})
      idx = refs[obj.object_id]
      return write_ref(idx) if idx
      refs[obj.object_id] = refs.size

      str = cstr
      fields.each do |f|
        str << write(obj.instance_variable_get(f), refs, crefs, trefs)
      end

      str
    end

    def write_object(obj, refs = {}, crefs = {}, trefs = {})
      idx = refs[obj.object_id]
      return write_ref(idx) if idx
      refs[obj.object_id] = refs.size

      klass = obj.class
      cref = crefs[klass]
      if cref
        cidx = cref.first
        fields = cref.last
        str = ''
      else
        fields = []
        cref = crefs[klass] = [crefs.size, fields]
        cidx = cref.first
        fields = obj.instance_variables
        str = [ BC_OBJECT_DEF ].pack('C') << write_string(klass) << write_int(fields.size)
        fields.map{|sym| sym.to_s[1..-1]}.each do |f|
          str << write_string(f)
        end
      end
      
      if cidx <= OBJECT_DIRECT_MAX
        str << [ BC_OBJECT_DIRECT + cidx ].pack('C')
      else
        str << [ BC_OBJECT ].pack('C') << write_int(cidx)
      end
      fields.each do |f|
        str << write(obj.instance_variable_get(f), refs, crefs, trefs)
      end

      str
    end

    def write_ref(val)
      [ BC_REF ].pack('C') << write_int(val)
    end

    def write_string(str)
      chunks, i, len = '', 0, str.size
      while len > 0x8000
        chunks << [ BC_STRING_CHUNK, 0x8000 ].pack('Cn') << print_string(str[i, i += 0x8000])
        len -= 0x8000
      end
      final = str[i..-1]
      chunks << if len <= STRING_DIRECT_MAX
        [ BC_STRING_DIRECT + len ].pack('C')
      elsif len <= STRING_SHORT_MAX
        [ BC_STRING_SHORT + (len >> 8), len ].pack('CC')
      else
        [ BC_STRING, len ].pack('Cn')
      end
      chunks << print_string(final)
    end

  end
end
