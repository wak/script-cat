#! /usr/bin/env ruby

require 'test/unit/assertions'
require 'strip'

class TC_SequenceReader < Test::Unit::TestCase
  def make(text)
     Sequence::Reader.new(ByteReader.new(text))
  end
  
  def test_plaintext
    @reader = make('abc')

    assert_equal Sequence::SingleSequence, @reader.read.class
    assert_equal Sequence::SingleSequence, @reader.read.class
    assert_equal Sequence::SingleSequence, @reader.read.class
    assert_equal nil, @reader.read
  end

  def test_CSI
    @reader = make("\e[34;1HZ")

    assert_equal Sequence::CSISequence, @reader.read.class
    assert_equal Sequence::SingleSequence, @reader.read.class
  end
end
