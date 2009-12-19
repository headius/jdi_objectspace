require 'object_walker'

class Foo
  def initialize(i)
    @i = i
  end
  
  def to_s
    "I am Foo \##{@i}"
  end
end
ary = Array.new(10) {|i| Foo.new(i)}

ObjectWalker.walk_objects(Foo) do |obj|
  puts "found object: #{obj}"
end
