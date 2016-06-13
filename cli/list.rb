#!/usr/bin/env ruby

require "bundler/setup"
require "trollop"
require "byebug"
require_relative "../model"

# list [-d|-f]
#   -f list files in the database
#   -d list directories in the database
#   -t list tags

options = Trollop::options do
  banner "Usage: #{$0} [options]"
  opt :files, "List files in the database"
  opt :directories, "List directories in the database"
  opt :tags, "List tags in the database"
  conflicts :files, :directories, :tags
end

case
when options.files
  Photo.all.map do |photo|
    photo.filename
  end.sort.each do |filename|
    puts filename
  end
when options.directories
  Photo.all(:fields => [:directory], :unique => true, :order => [:directory.asc]).each do |photo|
    puts "#{photo.directory}"
  end
when options.tags
  Tag.all(order: [:created_at.desc]).each do |tag|
    puts "%-20s %s" % [tag.tag, tag.created_at]
  end
end
