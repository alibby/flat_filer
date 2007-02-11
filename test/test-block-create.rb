
require 'flat_file'
require 'test/unit'

class BlockSimple < FlatFile
    add_field { |fd|
        fd.name = :record_id
        fd.width = 2
        fd.add_filter { |v| v.to_i }
        fd.add_formatter { |v| sprintf("%2s", v) }
    }

    add_field :name, :width => 5
end

class BlockTest < Test::Unit::TestCase
  def test_block
    file = File.dirname(__FILE__) + '/files/simple.txt'
    fh = open(file)

    x = BlockSimple.new
    count = 0
    x.each_record(fh) do |record,line|
        count+=1
        #puts "Line: #{line}"
        assert_equal(
            record.record_id,count, 
            "record_id should be <#{count}> but is <#{record.record_id}>"
        )
        assert_equal( line, record.to_s, "reassmbled record should be the same as it's origional from data file" )
    end
  end

end

