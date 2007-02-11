require 'flat_file'
require 'test/unit'

class People < FlatFile
    add_field :first_name, :width => 15, :filter => lambda { |v| v.strip }
    add_field :last_name, :width => 15, :filter => :strip
    add_field :email, :width => 30

    def self.strip(v)
        v.strip
    end
        
end

class CreateTest < Test::Unit::TestCase

  def test_create
    person = People.new_record
    person.first_name = "Andy"
    person.last_name = "Libby"
    person.email = "alibby@nowhere.org"
    #p person
 end
end
