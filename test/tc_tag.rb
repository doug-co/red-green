# File: tc_tag.rb

require_relative 'helper'

class TestTag < Minitest::Test

  def test_strip
    assert_equal(Tag.strip("&"), "&amp;")
    assert_equal(Tag.strip('"'), "&quot;")
    assert_equal(Tag.strip("'"), "&apos;")
    assert_equal(Tag.strip("<"), "&lt;")
    assert_equal(Tag.strip(">"), "&gt;")
    assert_equal(Tag.strip("a"), "a")
    assert_equal(Tag.strip(":"), ":")
    assert_equal(Tag.strip('<abc &b="12">\''), "&lt;abc &amp;b=&quot;12&quot;&gt;&apos;")
    assert_equal(Tag.strip('!@#$%^*()_-+={}[]:;,./?~`abcdefghijklmnopqrstuvwxyz'), '!@#$%^*()_-+={}[]:;,./?~`abcdefghijklmnopqrstuvwxyz')
  end

  def test_second
    assert(true, "failed miserably")
  end
end
