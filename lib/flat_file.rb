# A class to help parse and dump flat files
#
# This class provides an easy method of dealing with fixed
# field width flat files.
#
# For example a flat file containing information about people that
# looks like this:
#            10        20        30
#  012345678901234567890123456789
#  Walt      Whitman   18190531
#  Linus     Torvalds  19691228
#
#  class Poeple < FlatFile
#    add_field :first_name, :width => 10, :filter => :trim
#    add_field :last_name,  :width => 10, :filter => :trim
#    add_field :birthday,   :width => 8,  :filter => lambda { |v| Date.parse(v) }
#    pad       :auto_name,  :width => 2,
#
#  def self.trim(v)
#    v.trim
#  end
#
#  p = People.new
#  p.each_record(open('somefile.dat')) do |person|
#    puts "First Name: #{ person.first_name }"
#    puts "Last Name : #{ person.last_name}"
#    puts "Birthday  : #{ person.birthday}"
#
#    puts person.to_s
#  end
#
#
#
# An alternative method for adding fields is to pass a block to the
# add_field method.  The name is optional, but needs to be set either
# by passing the name parameter, or in the block that's passed. When
# you pass a block the first parameter is the FieldDef for the field
# being constructed for this fild.
#
#  class People < FlatFile
#    add_field { |fd|
#       fd.name = :first_name
#       fd.width = 10
#       fd.add_filter { |v| v.trim }
#       fd.add_formatter { |v| v.trim }
#       .
#       .
#    }
#  end
#
# Filters and Formatters
#
# Filters touch data when on the way in to the flat filer
# via each_record or create_record.
#
# Formatters are used when a record is converted into a
# string using to_s.
#
# Structurally, filters and formatters can be lambdas, code
# blocks, or symbols referencing methods.
#
# There's an expectaiton on the part of formatters of the
# type of a field value.  This means that the programmer
# needs to set the value of a field as a type that the formatter
# won't bork on.
#
# A good argument can be made to change filtering to happen any
# time a field value is assigned.  I've decided to not take this
# route because it'll make writing filters more complex.
#
# An example of this might be a date field.  If you've built up
# a date field where a string read from a file is marshalled into
# a Date object.  If you assign a string to that field and then
# attempt to export to a file you may run into problems.  This is
# because your formatters may not be resiliant enough to handle
# unepxected types.
#
# Until we build this into the system, write resiliant formatters
# OR take risks.  Practially speaking, if your system is stable
# with respect to input/ output you're probably going to be fine.
#
# If the filter were run every time a field value is assigned
# to a record, then the filter will need to check the value being
# passed to it and then make a filtering decision based on that.
# This seemed pretty unattractive to me.  So it's expected that
# when creating records with new_record, that you assign field
# values in the format that the formatter expect them to be in.
#
# Essentially, robustness needed either be in the filter or formatter,
# due to lazyness, I chose formatter.
#
# Generally this is just anything that can have to_s called
# on it, but if the filter does anything special, be cognizent
# of that when assigning values into fields.
#
# Class Organization
#
# add_field, and pad add FieldDef classes to an array.  This
# arary represents fields in a record.  Each FieldDef class contains
# information about the field such as it's name, and how to filter
# and format the class.
#
# add_field also adds to a variable that olds a pack format.  This is
# how the records parsed and assembeled.

class FlatFile
  class FlatFileException < Exception; end
  class ShortRecordError < FlatFileException; end
  class LongRecordError < FlatFileException; end
  class RecordLengthError < FlatFileException; end


  # A hash of data stored on behalf of subclasses.  One hash
  # key for each subclass.
  @@subclass_data = Hash.new(nil)

  # Used to generate unique names for pad fields which use :auto_name.
  @@unique_id = 0

  def next_record(io,&block)
    return nil if io.eof?
    required_line_length = self.class.get_subclass_variable 'width'
    line = io.readline
    line.chop!
    return nil if line.length == 0
    difference = required_line_length - line.length
    raise RecordLengthError.new(
      "length is #{line.length} but should be #{required_line_length}"
    ) unless(difference == 0)

    if block_given?
      yield(create_record(line, io.lineno), line)
    else
      create_record(line,io.lineno)
    end
  end

  # Iterate through each record (each line of the data file).  The passed
  # block is passed a new Record representing the line.
  #
  #  s = SomeFile.new
  #  s.each_record(open('/path/to/file')) do |r|
  #    puts r.first_name
  #  end
  #
  def each_record(io,&block)
    io.each_line do |line|
      required_line_length = self.class.get_subclass_variable 'width'
      #line = io.readline
      line.chop!
      next if line.length == 0
      difference = required_line_length - line.length
      raise RecordLengthError.new(
        "length is #{line.length} but should be #{required_line_length}"
      ) unless(difference == 0)
      yield(create_record(line, io.lineno), line)
    end
  end

  # create a record from line. The line is one line (or record) read from the
  # text file.  The resulting record is an object which.  The object takes signals
  # for each field according to the various fields defined with add_field or
  # varients of it.
  #
  # line_number is an optional line number of the line in a file of records.
  # If line is not in a series of records (lines), omit and it'll be -1 in the
  # resulting record objects.  Just make sure you realize this when reporting
  # errors.
  #
  # Both a getter (field_name), and setter (field_name=) are available to the
  # user.
  def create_record(line, line_number = -1) #:nodoc:
    h = Hash.new

    pack_format = self.class.get_subclass_variable 'pack_format'
    fields      = self.class.get_subclass_variable 'fields'

    f = line.unpack(pack_format)
    (0..(fields.size-1)).map do |index|
      unless fields[index].is_padding?
        h.store fields[index].name, fields[index].pass_through_filters(f[index])
      end
    end
    Record.new(self.class, h, line_number)
  end

  # Add a field to the FlatFile subclass.  Options can include
  #
  # :width - number of characters in field (default 10)
  # :filter - callack, lambda or code block for processing during reading
  # :formatter - callback, lambda, or code block for processing during writing
  #
  #  class SomeFile < FlatFile
  #    add_field :some_field_name, :width => 35
  #  end
  #
  def self.add_field(name=nil, options={},&block)
    options[:width] ||= 10;

    fields      = get_subclass_variable 'fields'
    width       = get_subclass_variable 'width'
    pack_format = get_subclass_variable 'pack_format'


    fd = FieldDef.new(name,options,self)
    yield(fd) if block_given?

    fields << fd
    width += fd.width
    pack_format << "A#{fd.width}"
    set_subclass_variable 'width', width
    fd
  end

  # Add a pad field.  To have the name auto generated, use :auto_name for
  # the name parameter.  For options see add_field.
  def self.pad(name, options = {})
    fd = self.add_field(
      name.eql?(:auto_name) ? self.new_pad_name : name,
      options
    )
    fd.padding = true
  end

  def self.new_pad_name #:nodoc:
    "pad_#{ @@unique_id+=1 }".to_sym
  end


  # Create a new empty record object conforming to this file.
  #
  #
  def self.new_record(model = nil, &block)
    fields = get_subclass_variable 'fields'

    record = Record.new(self)

    fields.map do |f|
      assign_method = "#{f.name}="
      value = model.respond_to?(f.name.to_sym) ? model.send(f.name.to_sym) : ""
      record.send(assign_method, value)
    end

    if block_given?
      yield block, record
    end

    record
  end

  # Return a lsit of fields for the FlatFile subclass
  def fields
    self.class.fields
  end

  def self.non_pad_fields
    self.fields.select { |f| not f.is_padding? }
  end

  def non_pad_fields
    self.non_pad_fields
  end

  def self.fields
    self.get_subclass_variable 'fields'
  end

  def self.has_field?(field_name)

    if self.fields.select { |f| f.name == field_name.to_sym }.length > 0
      true
    else
      false
    end
  end

  def self.width
    get_subclass_variable 'width'
  end

  # Return the record length for the FlatFile subclass
  def width
    self.class.width
  end

  # Returns the pack format which is generated from add_field
  # calls.  This format is used to unpack each line and create Records.
  def pack_format
    self.class.get_pack_format
  end

  def self.pack_format
    get_subclass_variable 'pack_format'
  end

  protected

  # Retrieve the subclass data hash for the current class
  def self.subclass_data #:nodoc:
    unless(@@subclass_data.has_key?(self))
      @@subclass_data.store(self, Hash.new)
    end

    @@subclass_data.fetch(self)
  end

  # Retrieve a particular subclass variable for this class by it's name.
  def self.get_subclass_variable(name) #:nodoc:
    if subclass_data.has_key? name
      subclass_data.fetch name
    end
  end

  # Set a subclass variable of 'name' to 'value'
  def self.set_subclass_variable(name,value) #:nodoc:
    subclass_data.store name, value
  end

  # Setup subclass class variables. This initializes the
  # record width, pack format, and fields array
  def self.inherited(s) #:nodoc:
    s.set_subclass_variable('width',0)
    s.set_subclass_variable('pack_format',"")
    s.set_subclass_variable('fields',Array.new)
  end
end
