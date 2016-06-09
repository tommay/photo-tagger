#!/usr/bin/env ruby

require "bundler/setup"
require "trollop"
require "byebug"
require_relative "../model"

#options = Trollop::options do
#  banner "Usage: #{$0} tag..."
#end

photos = ARGV.map do |tag|
  tag =~ /^(-?)(.*)/
  [$1, Tag.all(:tag.like => $2).photos]
end

_, photos = photos.reduce do |(_, memo), (type, photos)|
  if type == "-"
    [nil, memo - photos]
  else
    [nil, memo & photos]
  end
end

filenames = photos.map do |photo|
  photo.filename
end

filenames.sort.each do |filename|
  print "#{filename}\0"
end
