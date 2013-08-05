require 'spec_helper'

module Hessian2
  describe StructWrapper do
		hash = { born_at: Time.new(2005, 3, 4), name: '阿门', price: 59.59 }
		hash2 = { born_at: Time.new(2009, 5, 8), name: '大鸡', price: 99.99 }

		# monkey = Monkey.new(hash)
		# monkey2 = Monkey.new(hash2)

		# aash = monkey.attributes
		# aash2 = monkey2.attributes

		# aonkey = AnotherMonkey.new(hash)
		# aonkey2 = AnotherMonkey.new(hash2)

		# whash = Hessian2::StructWrapper.new(MonkeyStruct, hash)
		# wmonkey = Hessian2::StructWrapper.new(MonkeyStruct, monkey)
		# waash = Hessian2::StructWrapper.new(MonkeyStruct, aash)
		# waonkey = Hessian2::StructWrapper.new(MonkeyStruct, aonkey)

		# whashes = Hessian2::StructWrapper.new([MonkeyStruct], [hash, hash2])
		# wmonkeys = Hessian2::StructWrapper.new([MonkeyStruct], [monkey, monkey2])
		# waashes = Hessian2::StructWrapper.new([MonkeyStruct], [aash, aash2])
		# waonkeys = Hessian2::StructWrapper.new([MonkeyStruct], [aonkey, aonkey2])

		it "should raise error" do
			expect(lambda{ Hessian2::StructWrapper.new(MonkeyStruct) }).to raise_error
		end

		it "should wrap nil" do
			bin = Hessian2.write(Hessian2::StructWrapper.new(MonkeyStruct, nil))

			_monkey = Hessian2.parse(bin, MonkeyStruct)
			expect(_monkey).to eq(nil)
		end

		it "should wrap hash" do
			bin = Hessian2.write(Hessian2::StructWrapper.new(MonkeyStruct, hash))

			_monkey = Hessian2.parse(bin, MonkeyStruct)
			expect([ _monkey.born_at, _monkey.name, _monkey.price ]).to eq([ hash[:born_at], hash[:name], hash[:price] ])
		end

		it "should wrap monkey" do
			bin = Hessian2.write(Hessian2::StructWrapper.new(MonkeyStruct, Monkey.new(hash)))

			_monkey = Hessian2.parse(bin, MonkeyStruct)
			expect([ _monkey.born_at, _monkey.name, _monkey.price ]).to eq([ hash[:born_at], hash[:name], hash[:price] ])
		end

		it "should wrap another monkey" do
			bin = Hessian2.write(Hessian2::StructWrapper.new(MonkeyStruct, AnotherMonkey.new(hash)))

			_monkey = Hessian2.parse(bin, MonkeyStruct)
			expect([ _monkey.born_at, _monkey.name, _monkey.price ]).to eq([ hash[:born_at], hash[:name], hash[:price] ])
		end

		it "should wrap hash array" do
			bin = Hessian2.write(Hessian2::StructWrapper.new([MonkeyStruct], [hash, nil, hash2]))

			_monkey1, _monkey2, _monkey3 = Hessian2.parse(bin, [MonkeyStruct])
			expect([ _monkey1.born_at, _monkey1.name, _monkey1.price, _monkey2, _monkey3.born_at, _monkey3.name, _monkey3.price ]).to eq([ hash[:born_at], hash[:name], hash[:price], nil, hash2[:born_at], hash2[:name], hash2[:price] ])
		end
		

		# puts 'wrap hashes'

		# hashesbin = Hessian2.write(whashes)
		# puts hashesbin.inspect

		# sonkeys = Hessian2.parse(hashesbin, [MonkeyStruct])
		# puts sonkeys.inspect

		# puts 'wrap monkeys'

		# monkeysbin = Hessian2.write(wmonkeys)
		# puts monkeysbin.inspect

		# sonkeys = Hessian2.parse(monkeysbin, [MonkeyStruct])
		# puts sonkeys.inspect

		# puts 'wrap aashes'

		# aashesbin = Hessian2.write(waashes)
		# puts aashesbin.inspect

		# sonkeys = Hessian2.parse(aashesbin, [MonkeyStruct])
		# puts sonkeys.inspect

		# puts 'wrap aonkeys'

		# aonkeysbin = Hessian2.write(waonkeys)
		# puts aonkeysbin.inspect

		# sonkeys = Hessian2.parse(aonkeysbin, [MonkeyStruct])
		# puts sonkeys.inspect
	end
end