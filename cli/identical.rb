#!/usr/bin/env ruby

require "bundler/setup"
require "trollop"
require "pathname"
require "byebug"
require_relative "../model"

# identical file
#   List all the databased files identical to filename.

options = Trollop::options do
  banner "Usage: #{$0} [options] file"
end

photo = Photo.find(ARGV[0])
if !photo
  puts "#{ARGV[0]} not found"
  exit(1)
end

photo.identical.each do |identical|
  puts identical.filename
end
