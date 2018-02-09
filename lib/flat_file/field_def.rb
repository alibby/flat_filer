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
    attr :name, true
    attr :width, true
    attr :filters, true
    attr :formatters, true
    attr :file_klass, true
    attr :padding, true
    attr :map_in_proc, true
    attr :aggressive, true
    attr :default, true

    # Create a new FeildDef, having name and width. klass is a reference to the FlatFile
    # subclass that contains this field definition.  This reference is needed when calling
    # filters if they are specified using a symbol.
    #
    # Options can be :padding (if present and a true value, field is marked as a pad field),
    # :width, specify the field width, :formatter, specify a formatter, :filter, specify a
    # filter.
    #
    # The option :default => 'value' may be used to specify a default value to be mapped
    # into a model field provided the flat filer record is empty.

    def initialize(name=null,options={},klass={})
      @name = name
      @width = 10
      @filters = Array.new
      @formatters = Array.new
      @file_klass = klass
      @padding = options.delete(:padding)
      @default = options.has_key?(:default) ? options.delete(:default) :  ""

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
end
