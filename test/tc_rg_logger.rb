# File:  tc_simple_number.rb

require_relative 'helper'

class TestRGLogger < Minitest::Test

  def setup
    @obj = Object.new
    @obj.extend(RGLogger)
    @obj.set_logger do |msg| puts msg end
  end
  
  def test_log
    assert_equal(@obj.logger.class, Proc)
    assert_output("test\n") do
      @obj.log("test")
    end
  end

end
