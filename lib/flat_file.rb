#!/usr/bin/ruby -w

require 'rubygems'
require 'breakpoint'

# A class to help parse and dump flat files
#
# A flat file provides the ability to create subclasses
# that make prsing, handling records form, and creating 
# fixed with field flat files.
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
#  p = People.new(open('somefile.dat'))
#  p.each_record do |person|
#    puts "First Name: #{ person.first_name }"
#    puts "Last Name : #{ person.last_name}"
#    puts "Birthday  : #{ person.birthday}"
#  end
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
#       .
#  end
#
#
#
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
        attr :filter, true
        attr :formatter, true
        attr :file_klass, true

        # Create a new FeildDef, having name and width. 
        # klass is a reference to the FlatFile subclass that
        # contains this field definition.  This reference
        # is needed when calling filters if they are specified
        # using a symbol.
        def initialize(name=null,options={},klass={},&block)
            @name = name
            @width = 10
            @filters = Array.new
            @formatters = Array.new
            @file_klass = klass

            add_filter(options[:filter]) if options.has_key?(:filter)
            add_formatter(options[:formatter]) if options.has_key?(:formatter)
            @width = options[:width] if options.has_key?(:width)

            if block_given?
                yield self
            end
        end

        # Add a filter.  Filters are used for processing field
        # data when a flat file is being processed.  For fomratting
        # the data when writing a flat file, see add_formatter
        def add_filter(filter=nil,&block) #:nodoc:
            @filters.push(filter) unless filter.nil?
            @filters.push(block) if block_given?
        end

        # Add a formatter.  Formatters are used for formatting a field
        # for rendering a record, or writing it to a file in the desired format.
        def add_formatter(formatter=nil,&block) #:nodoc:
            @formatters.push(formatter)
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

        protected

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

        # Create a new Record from a hash of fields
        def initialize(fields,klass)
            @fields = fields
            @klass = klass
        end

        # Catches method calls and returns field values 
        # or raises an Error.
        def method_missing(method,params=nil)
            if(method.to_s.match /^(.*)=$/)
                if(fields.has_key?($1.to_sym)) 
                    @fields.store($1.to_sym,params)
                else
                    reaise Error.new("Unknown method: #{ method }")
                end
            else
                if(fields.has_key? method)
                    @fields.fetch(method)
                else
                    reaise Error.new("Unknown method: #{ method }")
                end
            end
        end

        def to_s
            #puts klass.pack_format
            #puts @fields.values.inspect

            klass.fields.map { |field_def|
                field_def.pass_through_formatters(@fields[ field_def.name ].to_s)
            }.pack(klass.pack_format)
        end
    end

    # A hash of data stored on behalf of subclasses.  One hash
    # key for each subclass.
    @@subclass_data = Hash.new(nil)

    # Used to generate unique names for pad fields which use :auto_name.
    @@unique_id = 0


    # Iterate through each record (each line of the data file).  The passed
    # block is passed a new Record representing the line.
    #
    #  s = SomeFile.new( open ( '/path/to/file' ) )
    #  s.each_record do |r|
    #    puts r.first_name
    #  end
    #
    def each_record(io)
        required_line_length = self.class.get_subclass_variable 'width'
        #puts "Required length: #{required_line_length}"
        io.each_line do |line|
            line.chop!
            next if line.length == 0
            difference = required_line_length - line.length
            if difference < 0
                raise LongRecordError.new("record too long (#{difference.abs}) line #{io.lineno}")
            elsif difference > 0
                raise ShortRecordError.new("record too short (#{difference.abs}) line #{io.lineno}")
            else
                yield create_record(line), line
            end
        end
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
        
       
        fd = FieldDef.new(name,options,self) { |f| yield(f) if block_given? }

        fields << fd
        width += fd.width
        pack_format << "A#{fd.width}"
        set_subclass_variable 'width', width
    end

    # Add a pad field.  To have the name auto generated, use :auto_name for
    # the name parameter.  For options see add_field.
    def self.pad(name, options = {})
        self.add_field(
            name.eql?(:auto_name) ? self.new_pad_name : name,
            options
        )
    end

    def self.new_pad_name #:nodoc:
        "pad_#{ @@unique_id+=1 }".to_sym
    end


    # Create a new empty record object conforming to this file.
    def self.new_record
        fields = get_subclass_variable 'fields'
        Record.new( Hash[*fields.map {|f| [f.name, ""] }.flatten], self )
    end

    # Return a lsit of fields for the FlatFile subclass
    def fields 
        self.fields
    end

    def self.fields
        self.get_subclass_variable 'fields'
    end

    # Return the record length for the FlatFile subclass 
    def width 
        self.class.get_subclass_viariable 'width'
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

    # create a record from line.  
    def create_record(line) #:nodoc:
        h = Hash.new 

        pack_format = self.class.get_subclass_variable 'pack_format'
        fields      = self.class.get_subclass_variable 'fields'
        
        f = line.unpack(pack_format)
        (0..(fields.size-1)).map do |index|
            h.store fields[index].name, fields[index].pass_through_filters(f[index])
        end
        Record.new(h,self.class)
    end
end

