#!/usr/bin/env ruby

require "bundler/setup"
require "optparse"
require "byebug"

require_relative "../model"
require_relative "../files"

add = []
remove = []
recurse = false

OptionParser.new do |opts|
  opts.banner = "Usage: $0 [options] [filename...]"

  opts.on("-a", "--add TAG", "Add TAG to files") do |tag|
    add << tag
  end

  opts.on("-R", "--remove TAG", "Remove TAG from files") do |tag|
    remove << tag
  end

  opts.on("-r", "Recurse directories") do
    recurse = true
  end

  opts.on("-h", "--help", "Print this help") do
    puts opts
    exit
  end
end.parse!

def tag(filename, add, remove)
  photo = Photo.find_or_create(filename)

  add.each do |tag|
    photo.add_tag(tag)
  end

  remove.each do |tag|
    photo.remove_tag(tag)
  end
end

ARGV.each do |filename|
  Files.image_files(filename, recurse).each do |file|
    tag(file, add, remove)
  end
end
