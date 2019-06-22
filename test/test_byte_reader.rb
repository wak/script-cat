#! /usr/bin/env ruby

require 'test/unit/assertions'
require 'strip'

class TC_ByteReader < Test::Unit::TestCase
  def test_getc
    @reader = ByteReader.new('abcdefg')

    assert_equal 'a', @reader.getc
    assert_equal 'b', @reader.getc
  end

  def test_eof
    @reader = ByteReader.new('XY')

    assert_false @reader.eof?
    @reader.getc
    
    assert_false @reader.eof?
    @reader.getc

    assert_true @reader.eof?
    assert_equal nil, @reader.getc
  end
end
