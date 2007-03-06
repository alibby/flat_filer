
require 'flat_file'
require 'test/unit'
require 'rubygems'
require 'breakpoint'

class Simple < FlatFile
    add_field :record_id, :width => 2, :filter => :before_filter, :formatter => lambda { |f| sprintf("%2s", f) }
    add_field :name, :width => 5
    def self.before_filter(f) 
        f.to_i
    end
end

class BasicTest < Test::Unit::TestCase

  def test_basic
    file = File.dirname(__FILE__) + '/files/simple.txt'
    fh = open(file)

    x = Simple.new
    count = 0
    x.each_record(fh) do |record,line|
        count+=1
        #puts "Line: #{line}"
        #puts "Record: "
        #p record
        assert_equal(
            record.record_id,count, 
            "record_id should be <#{count}> but is <#{record.record_id}>"
        )
        assert_equal( line, record.to_s, "reassmbled record should be the same as it's origional from data file" )
    end
  end

end

