#! /usr/bin/env ruby

require 'test/unit/assertions'
require 'script-cat'

class TC_Screen < Test::Unit::TestCase
  def setup
    @screen = Screen.new
  end
  
  def test_write
    @screen.write_char('a')
    assert_equal 'a', @screen.text
  end

  def test_movement
    @screen.right(1)
    @screen.write_char('R')
    @screen.down(2)
    @screen.write_char('D')
    @screen.left(3)
    @screen.write_char('L')
    @screen.up(1)
    @screen.write_char('U')

    assert_equal " R\n U\nL D", @screen.text
  end

  def test_erase_right
    'abcdefghijklmn'.each_char {|c| @screen.write_char(c) }
    @screen.move_column(3)
    @screen.erase_right
    
    assert_equal 'ab', @screen.text
  end
  
  def test_erase_left
    'abcdefghijklmn'.each_char {|c| @screen.write_char(c) }
    @screen.move_column(4)
    @screen.erase_left
    
    assert_equal '    efghijklmn', @screen.text
  end

  def test_insert
    @screen.write_char('a')
    @screen.insert(5, 'x')
    @screen.write_char('b')

    assert_equal 'abxxxx', @screen.text
  end

  def test_delete
    'aaxxxxx'.each_char {|c| @screen.write_char(c) }
    @screen.left(5)
    @screen.delete(5)
    assert_equal 'aa', @screen.text
  end
end
