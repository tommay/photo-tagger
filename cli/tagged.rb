#!/usr/bin/env ruby

require "bundler/setup"
require "trollop"
require "byebug"
require_relative "../model"

options = Trollop::options do
  banner "Usage: #{$0} tag..."
end

ARGV.map do |tag|
  Tag.all(:tag.like => tag).photos
end.reduce do |memo, photos|
  memo & photos
end.map do |photo|
  photo.filename
end.sort.each do |filename|
  puts filename
end
