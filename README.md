# hessian2

like json, additionally, 麻绳2 parse your object as a struct.

hessian2 implements hessian 2.0 protocol. look [web services protocol](http://hessian.caucho.com/doc/hessian-ws.html) and [serialization protocol](http://hessian.caucho.com/doc/hessian-serialization.html).

## comparing

yajl-ruby: json, fast.

msgpack: binary, faster.

protobuf: encoding your object with schema.

marshal: powerful, fast, but ruby only.

hessian2: powerful as marshal but parse object to struct, clean api, smaller.

## install

```
gem install hessian2
```

## serializing

```
require 'hessian2'
```

``` ruby
attributes = { born_at: Time.new(2009, 5, 8), name: '大鸡', price: 99.99 }
monkey = Monkey.new(attributes)
#=> #<Monkey id: nil, born_at: "2009-05-08 00:00:00", name: "\u5927\u9E21", price: #<BigDecimal:2b7c568,'0.9998999999 999999E2',27(45)>>

bin = Hessian2.write(monkey)
```

## deserializing 

``` ruby
monkey = Hessian2.parse(bin)
#=> #<struct id=nil, born_at=2009-05-08 00:00:00 +0800, name="\u5927\u9E21", price=99.99>
```

## struct wrapper 

for hash and object, only send values that specified.

``` ruby
MonkeyStruct = Struct.new(:born_at, :name)

wrapped_monkey = Hessian2::StructWrapper.new(MonkeyStruct, monkey)
bin = Hessian2.write(wrapped_monkey)
```

parsing values-binary to a monkey struct

``` ruby
monkey = Hessian2.parse(bin, MonkeyStruct)
#=> #<struct born_at=2009-05-08 00:00:00 +0800, name="\u5927\u9E21">
```

monkeys

``` ruby
wrapped_monkeys = Hessian2::StructWrapper.new([MonkeyStruct], monkeys)
bin = Hessian2.write(wrapped_monkeys)

monkeys = Hessian2.parse(bin, [MonkeyStruct])
```

struct wrapper supports: hash, object, [hash, [object

## class wrapper

for statically typed languages.

``` ruby
wrapped_monkey = Hessian2::ClassWrapper.new('com.sun.java.Monkey', monkey)
```

monkeys

``` ruby
wrapped_monkeys = Hessian2::ClassWrapper.new('[com.sun.java.Monkey', monkeys)
```

class wrapper supports: hash, object, [hash, [object

## type wrapper

wrap a string to long

``` ruby
str = '-0x8_000_000_000_000_000'
heslong = Hessian2::TypeWrapper.new(:long, str)
```

wrap a file to binary

``` ruby
binstr = IO.binread(File.expand_path("../Lighthouse.jpg", __FILE__))
hesbin = Hessian2::TypeWrapper.new(:bin, binstr)
```

there are types: 'L', 'I', 'B', '[L', '[I', '[B', :long, :int, :bin, [:long], [:int], [:bin]

## :symbolize_keys parser option

``` ruby
bin = Hessian2.write(attributes)
hash = Hessian2.parse(bin, nil, symbolize_keys: true)
#=> {:born_at=>2009-05-08 00:00:00 +0800, :name=>"\u5927\u9E21", :price=>99.99}
```

## client

``` ruby
url = 'http://127.0.0.1:9292/monkey'
client = Hessian2::Client.new(url)
```

call remote method, send a monkey

``` ruby
client.send_monkey(monkey)
```

## service

extend hessian handler

``` ruby
class MonkeyService
  extend Hessian2::Handler

  def self.send_monkey(monkey)
  # ...
end
```

handle request

``` ruby
post '/monkey' do
  MonkeyService.handle(request.body.read)
end
```

## todo

supports packet and envelope

write in c

## authors

[takafan](http://hululuu.com)
