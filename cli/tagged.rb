#!/usr/bin/env ruby

require "bundler/setup"
require "optimist"
require "strscan"
require "pratt_parser"
require "byebug"
require_relative "../model"
require_relative "../files"
require_relative "helpers"

options = Optimist::options do
  banner "Usage: #{$0} [-]tag..."
  # I would like --null's short option to be -0 ala xargs but optimist
  # doesn't allow short options to be numbers for some reason.
  opt :null, "Null-terminate output filenames", :short => "-n"
  opt :tags, "Show files' tags"
  opt :ugly, "Show files' tags in tag -a ... format"
  opt :directories, "List only directories containing the files"
  opt :expr, "Expression to search for", type: String
  opt :wild, "Put wildcards around all search tags"
  conflicts :null, :tags, :ugly
  conflicts :directories, :tags, :ugly
  stop_on_unknown
  # tag may be:
  #   a simple string (non-blanks or double-quote delimited) to find photos
  #     tagged with that string
  #     % is a wildcard character that matches any string
  #   <date to find photos taken before date
  #   =date to find photos taken on a particular date
  #   >date to find photos taken after date
  #     dates look like YYYY-MM-DD and may be partial dates, so for example
  #     "=2013" will find all photos taken in 2013 and ">2012-10" will find
  #     all photos taken after the beginning of 2012-10.
  #  r:[12345]* to find all pictures with a particular rating or ratings,
  #    e.g., r:12 will find photos rated 1 and 2.  r: with no list will
  #    find unrated photos.
  # Any of the above "tags" may be preceeded by "-" to exclude matching photos.
  # Multiple tags separated by spaces will be combined so that only photos
  #   matching both tags will be returned.
  # Tags separated with "+" will return the union of both tags' matches.
  # Parentheses may be used to create complex expressions.
end

terminator = options.null ? "\0" : "\n"

@directories = {}

# Lexer for PrattParser to create the Photo collection based on a
# tag/date expression.

class Lexer
  # Tokens are:
  #  [-]tag
  #  <date
  #  =date
  #  >date
  #  r:[12345]*
  #  +
  #  (
  #  )
  # where tag is a string of non-blanks or delimited by double quotes
  # and date is a string of digits and dashes, any prefix of
  # yyyy-mm-dd.  TOKENS matches each token in the expression.  -tag
  # yields two tokens: ButNotToken which is an operator, and
  # LikeTagToken(tag).  AndToken is generated automatically between
  # two tag or date tokens that don't have an explicit operator (+ or
  # -) between them.  All operators have the same precedence and are
  # left-associative.
  #
  # None of this scanning stuff is pretty but I blame it on my desire
  # to support command lines like "tagged max boots" to find photos
  # tagged with both "max" and "boots", and "tagged 'max boots'" to
  # find photos with the single tag "max boots".  And also to allow
  # "tagged max -boots" to find photos tagged with "max' but not with
  # "boots".
  #
  # XXX This is still crap because the expression " will be handled as
  # a tag.

  TOKENS = /[+()]|[<>=][0-9\-]+|r:[1-5]*|-?"([^"]*)"|-?[^\s]+|\s+/

  # Note that new is overwritten to return an Enumerator, not a Lexer.

  def self.new(expression)
    scanner = StringScanner.new(expression)
    need_and = false
    Enumerator.new do |y|
      while !scanner.eos?
        case scanner.scan(TOKENS)
        when nil
          raise "scan error at #{scanner.rest}"
        when /^\s+$/
          # Ignore whitespace.
        when "("
          y << LeftParenToken.new
          need_and = false
        when ")"
          y << RightParenToken.new
          need_and = true
        when "+"
          y << PlusToken.new
          need_and = false
        when /^=(.*)/
          y << AndToken.new if need_and
          y << LikeDateToken.new($1)
          need_and = true
        when /^<(.*)/
          y << AndToken.new if need_and
          y << BeforeDateToken.new($1)
          need_and = true
        when /^>(.*)/
          y << AndToken.new if need_and
          y << AfterDateToken.new($1)
          need_and = true
        when /^r:([1-5]*)$/
          y << AndToken.new if need_and
          y << RatingToken.new($1)
          need_and = true
        when /^-"(.*)"/, /^-(.*)/
          y << ButNotToken.new
          y << LikeTagToken.new($1)
          need_and = true
        when /^"(.*)"/, /^(.*)/
          y << AndToken.new if need_and
          y << LikeTagToken.new($1)
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

  class PhotoToken < Token(100)
    def initialize(*args)
      @photos = photos(*args)
    end

    def nud(parser)
      @photos
    end
  end

  class LikeTagToken < PhotoToken
    def photos(tag)
      if tag =~ /%/
        Tag.where(Sequel.like(:tag, tag)).photos
      else
        Tag.where(tag: tag).photos
      end
    end
  end

  class LikeDateToken < PhotoToken
    def photos(date)
      Photo.where(Sequel.like(:taken_time, date + "%"))
    end
  end

  class BeforeDateToken < PhotoToken
    def photos(date)
      Photo.where{taken_time < date}
    end
  end

  class AfterDateToken < PhotoToken
    def photos(date)
      Photo.where{taken_time >= date}
    end
  end

  class RatingToken < PhotoToken
    def photos(ratings)
      if ratings == ""
        Photo.where(rating: nil)
      else
        Photo.where(rating: ratings.each_char.map(&:to_i))
      end
    end
  end

  def self.BinaryOpToken(op)
    Token(10).tap do |klass|
      klass.class_exec do
        define_method(:led) do |parser, left|
          left.send(op, parser.expression(lbp))
        end
      end
    end
  end

  AndToken = BinaryOpToken(:intersect)
  PlusToken = BinaryOpToken(:union)
  ButNotToken = BinaryOpToken(:except)

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

expression = options.expr || ARGV.map do |arg|
  case arg
  when /^[<>=]/
    arg
  when /^-(.*)/
    "-\"#{$1}\""
  when /^r:[1-5]*$/
    arg
  when /\+/
    arg
  else
    if !options.wild
      "\"#{arg}\""
    else
      "\"%#{arg}%\""
    end
  end
end.join(" ")

photos = PrattParser.new(Lexer.new(expression)).eval.order(:taken_time).all.select do |p|
  !p.deleted?
end

def quote(s)
  s.gsub(/\\/, "\\\\")
  s.gsub(/"/, "\\\"")
  s.gsub(/\$/, "\\$")
  "\"#{s}\""
end

if options.tags || options.ugly
  photos.each do |photo|
    filename = photo.filename
    tags = photo.tags.map{|t|t.tag}.sort
    if options.ugly
      tags.each { |t| print " -a #{quote(t)}" }
      puts " #{quote(filename)}"
    else
      puts "#{filename}: #{tags.join(", ")}"
    end
  end
else
  names =
    if !options.directories
      photos.map do |photo|
        photo.filename
      end
    else
      photos.map do |photo|
        photo.directory
      end.uniq
    end
  names.each do |name|
    print "#{name}#{terminator}"
  end
end
