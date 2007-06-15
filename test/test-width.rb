require 'flat_file'
require 'test/unit'
require 'rubygems'
require 'breakpoint'

class Simple < FlatFile
    add_field :record_id, :width => 2, :filter => :before_filter, :formatter => lambda { |f| sprintf("%2s", f) }
    add_field :name, :width => 5
end

class WidthTest < Test::Unit::TestCase
  def test_width
    assert_equal(1,1, ' 1 == 1 ')
    assert_equal(7, Simple.width, "width should be 7")
    assert_equal(7, Simple.new.width, "width should be 7")
  end
end

