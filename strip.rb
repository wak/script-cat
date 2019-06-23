#! /usr/bin/env ruby
# coding: utf-8

require 'pp'
require 'getoptlong'

class Screen
  def initialize
    @row = 0
    @column = 0
    @screen = [[]]
    @alternative_screen_buffer = false
    @bracketed_paste_mode = false
  end
  
  def down(n)
    return if @alternative_screen_buffer
    
    @row.upto(@row + n) {|n|
      @screen[n] = [] if @screen.size <= n
    }
    @row = @row + n
  end

  def up(n)
    return if @alternative_screen_buffer
    
    @row = [@row - n, 0].max
  end

  def left(n)
    return if @alternative_screen_buffer
    
    @column = [@column - n, 0].max
  end

  def right(n)
    return if @alternative_screen_buffer
    
    @column += n
  end

  def move(row, column)
    return if @alternative_screen_buffer
    
    @row = [row - 1, 0].max
    @column = [column - 1, 0].max
  end

  def move_column(column)
    return if @alternative_screen_buffer
    
    @column = [column - 1, 0].max
  end

  def move_to_last_row
    return if @alternative_screen_buffer
    
    @row = @screen.size - 1
  end

  def erase_right
    return if @alternative_screen_buffer
    
    @screen[@row] = @screen[@row][0...@column]
  end

  def erase_left
    return if @alternative_screen_buffer
    
    0.upto(@column) {|i|
      @screen[@row][i] = nil
    }
  end

  def erase_line
    return if @alternative_screen_buffer
    
    @screen[@row] = []
  end

  def write_char(c)
    return if @alternative_screen_buffer
    
    @screen[@row][@column] = c
    @column += 1
  end

  def turn_on_bracketed_paste_mode
    @bracketed_paste_mode = true
  end
  
  def turn_off_bracketed_paste_mode
    @bracketed_paste_mode = false
  end

  def turn_on_alternative_screen_buffer
    # Alternative Screen Buffer 有効時の出力はすべて破棄する。
    # テキストエディタでの編集時にASBが有効になる。
    # 
    # 値を残したい場合は、grepやdiffで確認すること。
    
    @alternative_screen_buffer = true
  end
  
  def turn_off_alternative_screen_buffer
    @alternative_screen_buffer = false
  end

  def dump
    pp @screen
  end

  def text(newline = "\n")
    result = @screen.map {|r| r.map{|c| c || ' ' }.join.rstrip }
    
    return '' if result.empty?
    result.delete_at(0) while !result.empty? and result[0].strip.empty?
    
    return '' if result.empty?
    result.delete_at(-1) while !result.empty? and result[-1].strip.empty?

    return result.join(newline)
  end
end

class Terminal
  def initialize(text)
    @reader = Sequence::Reader.new(ByteReader.new(text))
    @screen = Screen.new
  end

  def simulate
    while s = @reader.read
      s.simulate(@screen)
    end

    return @screen
  end

  def text(newline = "\n")
    return @screen.text(newline) + newline
  end
end

class ByteReader
  def initialize(text)
    @text = text
    @position = 0
    @current = nil
  end

  def eof?
    @position >= @text.size
  end
  
  def getc
    return nil if eof?
    
    @current = @text[@position]
    @position += 1

    return @current
  end
end

module Sequence
  class Reader
    def initialize(input)
      @input = input
    end

    def read
      return nil if @input.eof?
      
      c = @input.getc
      
      if c == "\e"                 # 0x1b
        return read_escape_sequence
      else
        return SingleSequence.new(c)
      end
    end
    
    private

    def read_escape_sequence
      case c = @input.getc
      when '['
        return parse_CSI

      when 'P'
        return parse_DCS

      when '='
        # アプリケーションキーパッドモードにセットする(?)
        return IgnoredSequence.new(c)

      when '>'
        # 数値キーパッドモードにセットする(?)
        return IgnoredSequence.new(c)

      when ']'
        # XTERM sequence (OSC)
        return IgnoredSequence.new(c)

        
      when '\\'
        # ?
        return IgnoredSequence.new(c)

      else
        STDERR.puts "unsupported escape sequence (#{c})"
        return UnknownSequence.new(c)
      end
    end

    def parse_CSI
      # CSI - Control Sequence Introducer

      bytes = []
      loop {
        bytes << @input.getc
        break if bytes.last.match(/[@A-Za-z\[\]^_`{|}~]/)
      }

      return CSISequence.new(bytes.join)
    end

    def parse_DCS
      # Device Control Sequence
      
      case c = @input.getc
      when '+'
        d = []
        5.times { d << @input.getc }
        
        return DCSSequence.new(d.join)

      when '$'
        # 書式が正しいかわからない。
        d = []
        3.times { d << @input.getc }
        
        return DCSSequence.new(d.join)
        
      else
        STDERR.puts "unsupported DCS sequence (#{c})"
      end
    end
  end

  class SequenceBase
    def simulate(screen)
    end
  end

  class SingleSequence < SequenceBase
    def initialize(c)
      @character = c
    end

    def simulate(screen)
      case @character
      when "\n"
        screen.down(1)

      when "\r"
        screen.move_column(1)
        
      when "\b"
        screen.left(1)

      else
        screen.write_char(@character)
      end
    end

    def inspect
      "#<Sequence C c=#{@character.inspect}>"
    end
  end

  class IgnoredSequence < SequenceBase
    def initialize(type)
      @sequence_type = type
    end
    
    def inspect
      "#<Sequence IGN type='#{@sequence_type}'>"
    end
  end
  
  class UnknownSequence < SequenceBase
    def initialize(type)
      @sequence_type = type
    end
    
    def inspect
      "#<Sequence ??? type='#{@sequence_type}'>"
    end
  end
  
  class DCSSequence < SequenceBase
    def initialize(param)
      @param = param
    end

    def inspect()
      "#<Sequence DCS param=#{@param.inspect}>"
    end
  end
  
  class CSISequence < SequenceBase
    attr_reader :final_byte, :params
    
    def initialize(bytes)
      @bytes = bytes

      bytes = bytes.each_char.to_a
      @final_byte = bytes.pop
      
      @private_param = nil
      if bytes.first and bytes.first.match(/[<=>?]/)
        @private_param = bytes.shift
      end
      @params = bytes.join.split(';').map(&:to_i)

      @screen = nil
    end

    def inspect
      "#<Sequence CSI bytes=#{@bytes.inspect}>"
    end

    def simulate(screen)
      @screen = screen
      
      case @final_byte
      when 'K'
        simulate_erase_line

      when 'J'
        simulate_erase_screen

      when 'H'
        simulate_move_cursor

      when 'L'
        simulate_new_line

      when 'M'
        simulate_delete_n_line

      when 'm'
        simulate_SGR

      when 'A'                  # Cursor Up
        @screen.up(@params[0] || 1)
        
      when 'B'                  # Cursor Down
        @screen.down(@params[0] || 1)
        
      when 'C'                  # Cursor Forward
        @screen.right(@params[0] || 1)
        
      when 'D'                  # Cursor Back
        @screen.left(@params[0] || 1)

      when 'h'
        simulate_h
        
      when 'l'
        simulate_l

      when 'p'
        simulate_p

      when 'c'                  # DA2 (Secondary DA) ?
        # skip
        
      when 'r', 'n', '=', '>'
        # skip

      else
        notify_unsupported_sequence
      end
    end

    private
    
    def notify_unsupported_sequence
      STDERR.puts("unsupported CSI sequence (#{self.inspect})")
    end

    def simulate_h
      if @private_param == '?'
        case @params[0]
        when 2004
          @screen.turn_on_bracketed_paste_mode
          return

        when 1049
          @screen.turn_on_alternative_screen_buffer
          return

        when 1
          # アプリケーションカーソルキーモードをセットする(?)
          return

        when 7
          # 文字の折り返しを有効にする(?)
          return

        when 12
          # カーソルを点滅状態にする(?)
          return

        when 25
          # DECTCEM: カーソルを表示する。
          return
        end
      end
      
      notify_unsupported_sequence
    end

    def simulate_l
      if @private_param == '?'
        case @params[0]
        when 2004
          @screen.turn_off_bracketed_paste_mode
          return

        when 1049
          @screen.turn_off_alternative_screen_buffer
          return

        when 1
          # カーソルキーモードをセットする(?)
          return

        when 6
          # カーソル位置を絶対位置にセットする(?)
          return

        when 12
          # カーソルを点灯(非点滅)状態にする(?)
          return
          
        when 25
          # DECTCEM: カーソルを非表示にする。
          return
        end
      end
      
      notify_unsupported_sequence
    end

    def simulate_p
      if @bytes.include?('$')
        # DECRQM
        return
      end

      notify_unsupported_sequence
    end
    
    def simulate_erase_line
      case @params[0]
      when 0
        # erase char from cursor to end of line
        @screen.erase_right

      when 1
        # erase char from start of line to cursor
        @screen.erase_left

      when 2
        # erase entire line
        @screen.erase_line
      end
    end

    def simulate_erase_screen
      case @params[0]
      when 0
        # ?
        @screen.down(10)
        
      when 1
        # Erase characters from home to cursor
        @screen.down(10)

      when 2
        # Erase screen (scroll out)
        @screen.down(10)
      end
    end

    def simulate_move_cursor
      case @params.size
      when 0
        # 画面をクリアするときに発生するっぽい。
        @screen.down(1)
        
      when 2
        # $1行目の$2文字目にカーソルを移動する。
        # エディタ等を使用しなければ、画面は下に流れるだけのはず。
        # 最終行の$2文字目に移動とする。

        @screen.move_to_last_row
        @screen.move_column(params[1])
      else
        raise "ERROR #{self.inspect}"
      end
    end

    def simulate_new_line
      if @params.empty?
        @screen.down(1)
      else
        @screen.down(@params[0])
      end
    end

    def simulate_delete_n_line
      # 下N行を削除する。
      # データを残すため、何もしない。
      # 
      # 改行時に発生する。
      # エスケープシーケンスの流れとしては、1M → 1L となり、
      # 何もないはずの次の一行を削除してから、新しい行を挿入する…というような流れ。
    end

    def simulate_SGR
      # Select Graphic Rendition
      # 文字色や背景色などは、破棄する。
    end

    def simulate_CUF
      # Cursor Forward
      
      @screen.right(@params[0] || 1)
    end
  end
end

def parse_option
  option = {}

  parser = GetoptLong.new
  parser.set_options(['-i', GetoptLong::REQUIRED_ARGUMENT])
  parser.each_option do |name, arg|
    case name
    when '-i'
      option[:extension] = arg
    end
  end
  return option
end

def main
  option = parse_option
  inputfile = ARGV[0]
  out = STDOUT

  if inputfile.nil?
    STDIN.binmode
    bytes = STDIN.read
  else
    bytes = File.binread(inputfile)
  end
  
  terminal = Terminal.new(bytes)
  screen = terminal.simulate

  text = terminal.text("\r\n")
  if option[:extension] and inputfile
    File.open(inputfile + option[:extension], 'wb') {|f|
      f.write(text)
    }
  else
    print terminal.text("\r\n")
  end
end

if __FILE__ == $0
  main
end
