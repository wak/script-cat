#! /usr/bin/env ruby

require 'test/unit/assertions'
require "test/unit/rr"
require 'script-cat'

class TC_CSISequence < Test::Unit::TestCase
  def test_erase_line
    screen = Object.new
    mock(screen).erase_right
    s = Sequence::CSISequence.new('0K')
    s.simulate(screen)
    
    screen = Object.new
    mock(screen).erase_left
    s = Sequence::CSISequence.new('1K')
    s.simulate(screen)
    
    screen = Object.new
    mock(screen).erase_line
    s = Sequence::CSISequence.new('2K')
    s.simulate(screen)
  end
end
