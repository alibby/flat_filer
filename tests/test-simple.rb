
require 'flat_file'

class Simple < FlatFile
    set_subclass_variable('width',0)
    set_subclass_variable('pack_format',"")
    set_subclass_variable('fields',Array.new)

    add_field :rid
    add_field :name, :width => 5
    add_field :count, :width => 5
end

class People < FlatFile
    set_subclass_variable('width',0)
    set_subclass_variable('pack_format',"")
    set_subclass_variable('fields',Array.new)

    add_field :first_name, :width => 15
    add_field :last_name, :width => 15
    add_field :email, :width => 15
end

##################################################################################################

simple_file = Simple.new(open('files/simple.txt'))

puts "Simple created:"
p simple_file

simple_file.each_record do |record|
    puts "Got Record:"
    puts "ID      : #{record.rid }"
    puts "NAME    : #{record.name }"
    puts "COUNT   : #{record.count}"
end

puts "People"

people_file = People.new(open('files/people.txt'))

people_file.each_record do |record|
    puts "#{record.first_name} #{record.last_name} #{record.email}"
end


