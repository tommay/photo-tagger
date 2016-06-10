#!/usr/bin/env ruby

require "bundler/setup"
require "trollop"
require "byebug"
require_relative "../model"

options = Trollop::options do
  banner "Usage: #{$0} tag..."
  opt :tags, "Show files' tags"
  stop_on_unknown
end

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

if options.tags
  photos = photos.map do |photo|
    [photo.filename, photo.tags.map{|t|t.tag}.sort]
  end

  photos = photos.sort_by{|p| p[0]}

  photos.each do |photo|
    puts "#{photo[0]}: #{photo[1].join(", ")}"
  end
else
  filenames = photos.map do |photo|
    photo.filename
  end

  filenames.sort.each do |filename|
    print "#{filename}\0"
  end
end
