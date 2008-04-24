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
require 'core_extensions'
include CoreExtensions
class FlatFile

    class FlatFileException < Exception; end
    class ShortRecordError < FlatFileException; end
    class LongRecordError < FlatFileException; end
    class RecordLengthError < FlatFileException; end

    # A field definition tracks infomration that's necessary for
    # FlatFile to process a particular field.  This is typically 
    # added to a subclass of FlatFile like so:
    #
    #  class SomeFile < FlatFile
    #    add_field :some_field_name, :width => 35
    #  end
    #
    class FieldDef
        attr :name, true
        attr :width, true
        attr :filters, true
        attr :formatters, true
        attr :file_klass, true
        attr :padding, true
        attr :map_in_proc, true
        attr :aggressive, true

        # Create a new FeildDef, having name and width. klass is a reference to the FlatFile 
        # subclass that contains this field definition.  This reference is needed when calling 
        # filters if they are specified using a symbol.
        #
        # Options can be :padding (if present and a true value, field is marked as a pad field),
        # :width, specify the field width, :formatter, specify a formatter, :filter, specify a
        # filter.
        def initialize(name=null,options={},klass={})
            @name = name
            @width = 10
            @filters = Array.new
            @formatters = Array.new
            @file_klass = klass
            @padding = options.delete(:padding)

            add_filter(options[:filter]) if options.has_key?(:filter)
            add_formatter(options[:formatter]) if options.has_key?(:formatter)
            @map_in_proc = options[:map_in_proc]
            @width = options[:width] if options.has_key?(:width)
            @aggressive = options[:aggressive] || false
        end

        # Will return true if the field is a padding field.  Padding fields are ignored
        # when doing various things.  For example, when you're  populating an ActiveRecord
        # model with a record, padding fields are ignored.  
        def is_padding?
            @padding
        end

        # Add a filter.  Filters are used for processing field data when a flat file is being 
        # processed.  For fomratting the data when writing a flat file, see add_formatter
        def add_filter(filter=nil,&block) #:nodoc:
            @filters.push(filter) unless filter.nil?
            @filters.push(block) if block_given?
        end

        # Add a formatter.  Formatters are used for formatting a field
        # for rendering a record, or writing it to a file in the desired format.
        def add_formatter(formatter=nil,&block) #:nodoc:
            @formatters.push(formatter) if formatter
            @formatters.push(block) if block_given?
        end

        # Filters a value based on teh filters associated with a 
        # FieldDef.
        def pass_through_filters(v) #:nodoc:
            pass_through(@filters,v)
        end

        # Filters a value based on the filters associated with a
        # FieldDef.
        def pass_through_formatters(v) #:nodoc:
            pass_through(@formatters,v)
        end

        #protected

        def pass_through(what,value) #:nodoc:
            #puts "PASS THROUGH #{what.inspect} => #{value}"
            what.each do |filter|
               value  = case
                    when filter.is_a?(Symbol)
                        #puts "filter is a symbol"
                        @file_klass.send(filter,value)
                    when filter_block?(filter)
                        #puts "filter is a block"
                        filter.call(value)
                    when filter_class?(filter)
                        #puts "filter is a class"
                        filter.filter(value)
                    else
                        #puts "filter not valid, preserving"
                        value
                    end
            end
            value
        end

        # Test to see if filter is a filter block.  A filter block
        # can be called (using call) and takes one parameter
        def filter_block?(filter) #:nodoc:
            filter.respond_to?('call') && ( filter.arity >= 1 || filter.arity <= -1 )
        end
        
        # Test to see if a class is a filter class.  A filter class responds
        # to the filter signal (you can call filter on it).  
        def filter_class?(filter) #:nodoc:
            filter.respond_to?('filter')
        end
    end

    # A record abstracts on line or 'record' of a fixed width field.
    # The methods available are the kes of the hash passed to the constructor.
    # For example the call:
    #
    #  h = Hash['first_name','Andy','status','Supercool!']
    #  r = Record.new(h)
    #
    # would respond to r.first_name, and r.status yielding 
    # 'Andy' and 'Supercool!' respectively.
    #
    class Record
        attr_reader :fields
        attr_reader :klass
        attr_reader :line_number

        # Create a new Record from a hash of fields
        def initialize(klass,fields=Hash.new,line_number = -1,&block)
            @fields = Hash.new()
            @klass = klass
            @line_number = line_number
           
            klass_fields = klass.get_subclass_variable('fields')

            klass_fields.each do |f|
		        @fields.store(f.name, "")
            end

	        @fields.merge!(fields)

            @fields.each_key do |k|
              @fields.delete(k) unless klass.has_field?(k)
            end

            yield(block, self)if block_given?
            
            self
        end

        def map_in(model)
            @klass.non_pad_fields.each do |f|
                next unless(model.respond_to? "#{f.name}=")
                if f.map_in_proc
                    f.map_in_proc.call(model,self)
                else
                    model.send("#{f.name}=", send(f.name)) if f.aggressive or model.send(f.name).blank?
                end
            end
        end

        # Catches method calls and returns field values or raises an Error.
        def method_missing(method,params=nil)
            if(method.to_s.match(/^(.*)=$/))
                if(fields.has_key?($1.to_sym)) 
                    @fields.store($1.to_sym,params)
                else
                    raise Exception.new("Unknown method: #{ method }")
                end
            else
                if(fields.has_key? method)
                    @fields.fetch(method)
                else
                    raise Exception.new("Unknown method: #{ method }")
                end
            end
        end

        # Returns a string representation of the record suitable for writing to a flat
        # file on disk or other media.  The fields are parepared according to the file
        # definition, and any formatters attached to the field definitions.
        def to_s
            klass.fields.map { |field_def|
		        field_name = field_def.name.to_s
		        v = @fields[ field_name.to_sym ].to_s

                field_def.pass_through_formatters(
                    field_def.is_padding? ? "" : v
                )
            }.pack(klass.pack_format)
        end

        # Produces a multiline string, one field per line suitable for debugging purposes.
        def debug_string
            str = ""
            klass.fields.each do |f|
                if f.is_padding?
                    str << "#{f.name}: \n"
                else
                    str << "#{f.name}: #{send(f.name.to_sym)}\n"
                end
            end

            str
        end
    end

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
