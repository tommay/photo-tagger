#!/usr/bin/env ruby

require "bundler/setup"
require "trollop"
require "pratt_parser"
require "byebug"
require_relative "../model"

options = Trollop::options do
  banner "Usage: #{$0} [-]tag..."
  opt :nul, "Nul-terminate output filenames"
  opt :null, "Same as --nul"
  opt :tags, "Show files' tags"
  opt :ugly, "Show files' tags in tag -a ... format"
  conflicts :nul, :tags, :ugly
  conflicts :null, :tags, :ugly
  stop_on_unknown
end

terminator = (options.nul || options.null) ? "\0" : "\n"

# Lexer for PrattParser to create the Photo collection based on a
# tag/date expression.

class Lexer
  # Tokens are:
  #  [-]tag
  #  <date
  #  =date
  #  >date
  #  +
  #  (
  #  )
  # where tag and date are strings of non-blanks.  We split the
  # expression on delimiters and whitespace.  The delimiters are
  # returned as part of the token list, whitespace is discarded.  Note
  # that "-" is not a delimiter, since we want to use it as part of
  # dates like "2016-04-01".  But -tag returns two tokens: AndNotToken
  # which is an operator, and LikeTagToken(tag).  AndToken is
  # generated between two data tokens that don't have an explicit
  # operator (+ or -) between them.  All operators have the same
  # precedence and are left-associative.

  SPLIT = %r{([+()])|\s+}

  # Note that new is overwritten to return an Enumerator, not a Lexer.

  def self.new(expression)
    tokens = expression.split(SPLIT).reject{|x| x == ""}
    need_and = false
    Enumerator.new do |y|
      tokens.each do |token|
        case token
        when "("
          y << LeftParenToken.new
          need_and = false
        when ")"
          y << RightParenToken.new
          need_and = false
        when "+"
          y << PlusToken.new
          need_and = false
        when /=(.*)/
          y << AndToken.new if need_and
          y << LikeDateToken.new($1)
          need_and = true
        when /<(.*)/
          y << AndToken.new if need_and
          y << BeforeDateToken.new($1)
          need_and = true
        when />(.*)/
          y << AndToken.new if need_and
          y << AfterDateToken.new($1)
          need_and = true
        when /-(.*)/
          y << ButNotToken.new
          y << LikeTagToken.new($1)
          need_and = true
        else
          y << AndToken.new if need_and
          y << LikeTagToken.new(token)
          need_and = true
        end
      end
    end
  end

  def self.Token(_lbp)
    Class.new do
      define_method(:lbp) do
        _lbp
      end
    end
  end

  class LikeTagToken < Token(100)
    def initialize(tag)
      @photos =
        if tag =~ /%/
          Tag.all(:tag.like => tag).photos
        else
          Tag.all(:tag => tag).photos
        end
    end

    def nud(parser)
      @photos
    end
  end

  class LikeDateToken < Token(100)
    def initialize(date)
      @photos = Photo.all(:taken_time.like => date + "%")
    end

    def nud(parser)
      @photos
    end
  end

  class BeforeDateToken < Token(100)
    def initialize(date)
      @photos = Photo.all(:taken_time.lt => date)
    end

    def nud(parser)
      @photos
    end
  end

  class AfterDateToken < Token(100)
    def initialize(date)
      @photos = Photo.all(:taken_time.gte => date)
    end

    def nud(parser)
      @photos
    end
  end

  class AndToken < Token(10)
    def led(parser, left)
      left & parser.expression(lbp)
    end
  end

  class PlusToken < Token(10)
    def led(parser, left)
      left + parser.expression(lbp)
    end
  end

  class ButNotToken < Token(10)
    def led(parser, left)
      left - parser.expression(lbp)
    end
  end

  class LeftParenToken < Token(1)
    def nud(parser)
      parser.expression(lbp).tap do
        parser.expect(RightParenToken)
      end
    end
  end
  
  class RightParenToken < Token(1)
  end
end

expression = ARGV.join(" ")
photos = PrattParser.new(Lexer.new(expression)).eval

def quote(s)
  s.gsub(/\\/, "\\\\")
  s.gsub(/"/, "\\\"")
  s.gsub(/\$/, "\\$")
  "\"#{s}\""
end

if options.tags || options.ugly
  photos = photos.map do |photo|
    [photo.filename, photo.tags.map{|t|t.tag}.sort]
  end

  photos = photos.sort_by{|p| p[0]}

  photos.each do |photo|
    if options.ugly
      photo[1].each { |t| print " -a #{quote(t)}" }
      puts " #{quote(photo[0])}"
    else
      puts "#{photo[0]}: #{photo[1].join(", ")}"
    end
  end
else
  filenames = photos.map do |photo|
    photo.filename
  end

  filenames.sort.each do |filename|
    print "#{filename}#{terminator}"
  end
end
