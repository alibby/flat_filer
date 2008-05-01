require File.dirname(__FILE__) + "/../lib/core_extensions"
require 'spec'

describe Object, "blank?" do
  it "should return true for 0" do
    0.should be_blank
  end
  
  it "should return true for 0.0" do
    0.0.should be_blank
  end
  
  it "should return false for 1" do
    1.should_not be_blank
  end
  
  it "should return true for ''" do
    ''.should be_blank
  end
  
  it "should return false for 'moo'" do
    'moo'.should_not be_blank
  end
  
  it "should return true for nil" do
    nil.should be_blank
  end
  
  it "should return true for '  '" do
    '  '.should be_blank
  end  
end