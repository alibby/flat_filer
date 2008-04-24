module CoreExtensions
  class Object
    # An object is blank if it's nil, empty, or a whitespace string.
    # For example, "", "   ", nil, [], and {} are blank.
    #
    # This simplifies
    #   if !address.nil? && !address.empty?
    # to
    #   if !address.blank?
    def blank?
      if respond_to?(:empty?) && respond_to?(:strip)
        empty? or strip.empty?
      elsif respond_to?(:empty?)
        empty?
      else
        !self
      end
    end
  end
end
