require File.dirname(__FILE__) + "/../lib/flat_file"
require 'spec'

class PersonFile < FlatFile
    add_field :f_name, :width => 10

    add_field :l_name, :width => 10, :aggressive => true

    add_field :gender, :width => 1, :default => nil
    
    add_field :phone, :width => 10, 
        :map_in_proc => proc { |model, record|
            return if model.phone
            model.phone = record.phone
        }

    add_field :age, :width => 4, 
        :filter => proc { |v| v.to_i },
        :formatter => proc { |v| v.to_f.to_s }

    pad :auto_name, :width => 3
    add_field :ignore, :width => 3, :padding => true
end


describe FlatFile do 
     @@data = <<EOF
12345678901234567890123456789012345678901
f_name    l_name    g          age pad---
Captain   Stubing   M          4      xxx
No        Phone                5      xxx
Has       Phone     F11111111116      xxx

EOF

    @@lines = @@data.split("\n")

    before :all do 
        Struct.new("Person", :f_name, :l_name, :gender, :phone, :age, :ignore)
        @ff = PersonFile.new
    end

    before :each do 
        @io = StringIO.new(@@data)
    end 

    it "should not be nil " do
      @ff.should_not eql(nil)
    end

    it "should know pad fields" do 
        PersonFile.non_pad_fields.select { |f| f.is_padding? }.length.should equal(0)
    end
   
    it "should honor formatters" do 
        @ff.next_record(@io)
        @ff.next_record(@io)
        @ff.next_record(@io) do |r,line_number|
            age_as_float = r.to_s.split(/\s+/)[3]
            age_as_float.should ==('4.0')
        end
    end
    
    it "should honor filters" do 
        r = @ff.create_record("Captain   Stubing   4         ")
        r.age.class.should equal(Fixnum)
    end

    it "should process records" do 
        @ff.each_record(@io) do |r,l|
        end
        @io.eof?.should equal(true)
    end

    # In our flat file class above, the phone field
    # has a map_in_proc which does not overwrite the
    # attribute on the target model.
    #
    # A successful test will not overwrite the phone number.
    it "should not overwrite according to map proc" do 
        person = Struct::Person.new('A','Hole','M','5555555555','4')
        rec = @ff.create_record(@@lines[4])
        rec.map_in(person)
        person.phone.should eql("5555555555")
    end

    it "should overwrite when agressive" do 
        person = Struct::Person.new('A','Hole','M','5555555555','4')
        rec = @ff.create_record(@@lines[4])
        rec.map_in(person)
        person.l_name.should eql("Phone")
    end

    it "should overwrite according to map proc" do 
        person = Struct::Person.new('A','Hole','M','5555555555','4')
        rec = @ff.create_record(@@lines[4])
        rec.map_in(person)
        person.ignore.should eql(nil)
        person.f_name.should eql("A")
    end

    it "sould honor default value of (nil)" do 
        person = Struct::Person.new('A','Hole',"",'5555555555','4')
        rec = @ff.create_record(@@lines[3])
        rec.map_in(person)
        person.gender.should eql(nil)

        person = Struct::Person.new('A','Hole',nil,'5555555555','4')
        rec = @ff.create_record(@@lines[2])
        rec.map_in(person)
        person.gender.should eql("M")

        person = Struct::Person.new('A','Hole',"",'','4')
        rec = @ff.create_record(@@lines[3])
        rec.map_in(person)
        person.phone.should eql('')
    end
    
    it "should process all lines in a file" do 
        num_lines = @@data.split("\n").size() + 1  # for extra \n in file.
        
        count = 0
        @io.each_line do 
            count+=1
        end

        count.should == num_lines

    end
end


