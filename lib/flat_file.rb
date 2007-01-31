#!/usr/bin/ruby -w

class FlatFile

    # A field definition tracks infomration that's necessary for
    # FlatFile to process a particular field.  This is typically 
    # added to a subclass of FlatFile like so:
    #
    #  class SomeFile < FlatFile
    #    add_field :some_field_name, :width => 35
    #  end
    #
    class FieldDef
        attr_reader :name
        attr_reader :width

        # Create a new FeildDef, having name and width. 
        def initialize(name,width)
            @name = name
            @width = width
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

        # Create a new Record from a hash of fields
        def initialize(fields)
            @fields = fields
        end

        # Catches method calls and returns field values 
        # or raises an Error.
        def method_missing(method,params=nil)
            if(fields.has_key? method)
                @fields.fetch(method)
            else
                raise Error.new("method missing")
            end
        end
    end

    # A hash of data stored on behalf of subclasses.  One hash
    # key for each subclass.
    @@subclass_data = Hash.new(nil)
    attr_reader :io

    # Retrieve the subclass data hash for the current class
    def self.subclass_data
        unless(@@subclass_data.has_key?(self))
           @@subclass_data.store(self, Hash.new)
        end

        @@subclass_data.fetch(self)
    end

    # Retrieve a particular subclass variable for this class by it's name.
    def self.get_subclass_variable(name)
        if subclass_data.has_key? name
            subclass_data.fetch name
        end
    end

    # Set a subclass variable of 'name' to 'value'
    def self.set_subclass_variable(name,value)
        subclass_data.store name, value
    end

    # Create a new flat file, which will be read from the io handle 'io'
    def initialize(io)
        @io = io
    end

    # Iterate through each record (each line of the data file).  The passed
    # block is passed a new Record representing the line.
    #
    #  s = SomeFile.new( open ( '/path/to/file' ) )
    #  s.each_record do |r|
    #    puts r.first_name
    #  end
    #
    def each_record
        required_line_length = self.class.get_subclass_variable 'width'
        @io.each_line do |line|
            if line.length < required_line_length
                puts "SHORT RECORD"
            else
                yield create_record(line)
            end
        end
    end

    # Add a field to the FlatFile subclass.
    #
    #  class SomeFile < FlatFile
    #    add_field :some_field_name, :width => 35
    #  end
    #
    def self.add_field(name, options={})
        puts "Add field class #{ self.class }"
        options[:width] ||= 10;

        fields      = get_subclass_variable 'fields'
        width       = get_subclass_variable 'width'
        pack_format = get_subclass_variable 'pack_format'
    
        fields << FieldDef.new(name, options[:width])
        width += options[:width]
        pack_format << "a#{options[:width]}"
        set_subclass_variable 'width', width
    end

    protected

    # create a record from line.  
    def create_record(line)
        h = Hash.new 

        pack_format = self.class.get_subclass_variable 'pack_format'
        fields      = self.class.get_subclass_variable 'fields'
        
        f = line.unpack(pack_format)
        (0..(fields.size-1)).map do |index|
            h.store fields[index].name, f[index]
        end

        Record.new(h)
    end

    public 

    # Return a lsit of fields for the FlatFile subclass
    def fields
        self.class.get_subclass_viariable 'fields'
    end

    # Return the record length for the FlatFile subclass 
    def width
        self.class.get_subclass_viariable 'width'
    end
    
    # Returns the pack format which is generated from add_field
    # calls.  This format is used to unpack each line and create Records.
    def pack_format
        self.class.get_subclass_viariable 'pack_format'
    end
end

