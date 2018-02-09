require 'spec_helper'

class PersonFile < FlatFile
  add_field :f_name, :width => 10

  add_field :l_name, :width => 10, :aggressive => true

  add_field :gender, :width => 1, :default => nil

  add_field :phone, :width => 10,
    :map_in_proc => proc { |model, record|
    model.phone = record.phone unless model.phone
  }

  add_field :age, :width => 4,
    :filter => proc { |v| v.to_i },
    :formatter => proc { |v| v.to_f.to_s }

  pad :auto_name, :width => 3
  add_field :ignore, :width => 3, :padding => true
end


describe FlatFile do
  let(:data) do
    "12345678901234567890123456789012345678901\n" +
    "f_name    l_name    g          age pad---\n" +
    "Captain   Stubing   M          4      xxx\n" +
    "No        Phone                5      xxx\n" +
    "Has       Phone     F11111111116      xxx\n\n"
  end

  let(:lines) { data.split("\n") }
  let(:filer) { PersonFile.new }
  let(:io) { StringIO.new(data) }

  subject { filer }

  before :all do
    Struct.new("Person", :f_name, :l_name, :gender, :phone, :age, :ignore)
  end

  subject { should_not be_nil }

  it "should know pad fields" do
    expect(PersonFile.non_pad_fields.select { |f| f.is_padding? }.length).to eq 0
  end

  it "should honor formatters" do
    filer.next_record(io)
    filer.next_record(io)
    filer.next_record(io) do |r,line_number|
      age_as_float = r.to_s.split(/\s+/)[3]
      expect(age_as_float).to eq '4.0'
    end
  end

  it "should honor filters" do
    r = filer.create_record("Captain   Stubing   4         ")
    r.age.is_a? Numeric
  end

  it "should process records" do
    filer.each_record(io) do |r,l|
    end
    expect(io.eof?).to be_truthy
  end

  # In our flat file class above, the phone field
  # has a map_in_proc which does not overwrite the
  # attribute on the target model.
  #
  # A successful test will not overwrite the phone number.
  it "should not overwrite according to map proc" do
    person = ::Struct::Person.new('A','Hole','M','5555555555','4')
    rec = filer.create_record(lines[4])
    rec.map_in(person)
    expect(person.phone).to eq "5555555555"
  end

  it "should overwrite when agressive" do

    person = Struct::Person.new('A','Hole','M','5555555555','4')
    rec = filer.create_record(lines[4])
    rec.map_in(person)
    expect(person.l_name).to eql("Phone")
  end

  it "should overwrite according to map proc" do
    person = Struct::Person.new('A','Hole','M','5555555555','4')
    rec = filer.create_record(lines[4])
    rec.map_in(person)
    expect(person.ignore).to eql(nil)
    expect(person.f_name).to eql("A")
  end

  it "sould honor default value of (nil)" do
    person = Struct::Person.new('A','Hole',"",'5555555555','4')
    rec = filer.create_record(lines[3])
    rec.map_in(person)
    expect(person.gender).to eql(nil)

    person = Struct::Person.new('A','Hole',nil,'5555555555','4')
    rec = filer.create_record(lines[2])
    rec.map_in(person)
    expect(person.gender).to eql("M")

    person = Struct::Person.new('A','Hole',"",'','4')
    rec = filer.create_record(lines[3])
    rec.map_in(person)
    expect(person.phone).to eql('')
  end

  it "should process all lines in a file" do
    num_lines = data.split("\n").size() + 1  # for extra \n in file.

    count = 0
    io.each_line do
      count+=1
    end

    expect(count).to eq num_lines
  end
end
