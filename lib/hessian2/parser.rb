require 'hessian2/fault'

module Hessian2
  module Parser
    @@s_time = 0
    @@S_time = 0
    def parse(data)
      rets, refs, chunks = [], [], []
      t0 = Time.new
      while data[0] != 'z'
        rets << parse_object(data, refs, chunks)
      end
      puts "parse time: #{Time.new - t0}"
      puts "@@s_time: #{@@s_time}"
      puts "@@S_time: #{@@S_time}"
      rets.size == 1 ? rets.first : rets
    end

    private
    def parse_object(data, refs = [], chunks = [])
      t = data.slice!(0)
      case t
      when 'H'
        data.slice!(0, 2)
      when 'R'
        parse_object(data, refs, chunks)
      when 'c' # call
        data.slice!(0, 2)
        parse_object(data)
      when 'm' # method
        len = data.slice!(0, 2).unpack('n')[0]
        data.slice!(0, len)
      when 'r' # reply
        data.slice!(0, 2)
        parse_object(data)
      when 'f' # fault
        parse_object(data)
        code = parse_object(data)
        parse_object(data)
        message = parse_object(data)
        # parse_object(data)
        # detail = parse_object(data)
        raise Fault.new, code == 'RuntimeError' ? message : "#{code} - #{message}"
      when 'N' # null
        nil
      when 'T' # true
        true
      when 'F' # false
        false
      when 'I' # int
        data.slice!(0, 4).unpack('l>')[0] 
      when 'L' # long
        data.slice!(0, 8).unpack('q>')[0] 
      when 'D' # double
        data.slice!(0, 8).unpack('G')[0] 
      when 'd' # date
        val = data.slice!(0, 8).unpack('Q>')[0]
        Time.at(val / 1000, val % 1000 * 1000)
      when 'S', 's', 'X', 'x' # string, xml
        t0 = Time.new
        len = data.slice!(0, 2).unpack('n')[0]
        chunk = data.unpack("U#{len}")
        chunks << chunk
        data.slice!(0, chunk.pack('U*').bytesize)
        
        if 'sx'.include?(t)
          @@s_time += 1
          parse_object(data, refs, chunks)
        else
          str = chunks.flatten.pack('U*')
          chunks.clear
          @@S_time += 1
          str
        end
      when 'B', 'b' # binary
        len = data.slice!(0, 2).unpack('n')[0]
        chunk = data.slice!(0, len)
        chunks << chunk
        
        if t == 'b'
          parse_object(data, refs, chunks)
        else
          str = chunks.join
          chunks.clear
          str
        end
      when 'V' # list
        data.slice!(0, 3 + data.unpack('an')[1]) if data[0] == 't'
        data.slice!(0, 5) if data[0] == 'l'
        refs << (list = [])
        list << parse_object(data, refs) while data[0] != 'z'
        data.slice!(0)
        list
      when 'M' # map
        if data[0] == 't'
          puts data.slice!(0, 3 + data.unpack('an')[1])
        end
        refs << (map = {})
        map[parse_object(data, refs)] = parse_object(data, refs) while data[0] != 'z'
        data.slice!(0)
        map
      when 'R' # ref
        refs[data.slice!(0, 4).unpack('N')[0]]
      else
        raise "Invalid type: '#{t}'"
      end
    end

    def parse_simple_object(data, refs)
      t = data.slice!(0)
      case t
      when 'N' # null
        nil
      when 'T' # true
        true
      when 'F' # false
        false
      when 'I' # int
        data.slice!(0, 4).unpack('l>')[0] 
      when 'L' # long
        data.slice!(0, 8).unpack('q>')[0] 
      when 'D' # double
        data.slice!(0, 8).unpack('G')[0] 
      when 'd' # date
        val = data.slice!(0, 8).unpack('Q>')[0]
        Time.at(val / 1000, val % 1000 * 1000)
      when 'S', 'X' # string, xml
        t0 = Time.new
        len = data.slice!(0, 2).unpack('n')[0]
        chunk = data.unpack("U#{len}")
        data.slice!(0, chunk.pack('U*').bytesize)
        chunk.flatten.pack('U*')
      when 'B', 'b' # binary
        len = data.slice!(0, 2).unpack('n')[0]
        data.slice!(0, len)
      when 'M' # map
        data.slice!(0, 3 + data.unpack('an')[1]) if data[0] == 't'
        refs << (map = {})
        map[parse_simple_object(data, refs)] = parse_simple_object(data, refs) while data[0] != 'z'
        data.slice!(0)
        map
      when 'R' # ref
        refs[data.slice!(0, 4).unpack('N')[0]]
      else
        raise "Invalid type: '#{t}'"
      end
    end

  end 
end

class String
  include Hessian2::Parser
  def dehess
    rets, refs, chunks = [], [], []
    while self[0] != 'z'
      t = self.slice!(0)
      rets << case t
      when 'c' # call
        self.slice!(0, 2)
      when 'm' # method
        len = self.slice!(0, 2).unpack('n')[0]
        self.slice!(0, len)
      when 'r' # reply
        self.slice!(0, 2)
      when 'f' # fault
        # parse_object(data)
        # code = parse_object(data)
        # parse_object(data)
        # message = parse_object(data)
        # parse_object(data)
        # detail = parse_object(data)
        # raise Hessian2::Fault.new, code == 'RuntimeError' ? message : "#{code} - #{message}"
        raise Hessian2::Fault.new
      when 'N' # null
        nil
      when 'T' # true
        true
      when 'F' # false
        false
      when 'I' # int
        self.slice!(0, 4).unpack('l>')[0] 
      when 'L' # long
        self.slice!(0, 8).unpack('q>')[0] 
      when 'D' # double
        self.slice!(0, 8).unpack('G')[0] 
      when 'd' # date
        val = self.slice!(0, 8).unpack('Q>')[0]
        Time.at(val / 1000, val % 1000 * 1000)
      when 'S', 's', 'X', 'x' # string, xml
        t0 = Time.new
        len = self.slice!(0, 2).unpack('n')[0]
        chunk = self.unpack("U#{len}")
        chunks << chunk
        self.slice!(0, chunk.pack('U*').bytesize)
        
        if 'sx'.include?(t)
          @@s_time += 1
        else
          str = chunks.flatten.pack('U*')
          chunks.clear
          @@S_time += 1
          str
        end
      when 'B', 'b' # binary
        len = self.slice!(0, 2).unpack('n')[0]
        chunk = self.slice!(0, len)
        chunks << chunk
        
        if t == 'b'
        else
          str = chunks.join
          chunks.clear
          str
        end
      when 'V' # list
        self.slice!(0, 3 + self.unpack('an')[1]) if self[0] == 't'
        self.slice!(0, 5) if self[0] == 'l'
        refs << (list = [])
        list << parse_simple_object(self, refs) while self[0] != 'z'
        self.slice!(0)
        list
      when 'M' # map
        self.slice!(0, 3 + self.unpack('an')[1]) if self[0] == 't'
        refs << (map = {})
        map[parse_simple_object(self, refs)] = parse_simple_object(self, refs) while self[0] != 'z'
        self.slice!(0)
        map
      when 'R' # ref
        refs[self.slice!(0, 4).unpack('N')[0]]
      else
        raise "Invalid type: '#{t}'"
      end

    end
    rets.size == 1 ? rets.first : rets
  end
end