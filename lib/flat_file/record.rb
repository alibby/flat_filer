class FlatFile
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
          model.send("#{f.name}=", f.default) if model.send(f.name).blank?
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
end
