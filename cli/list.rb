#!/usr/bin/env ruby

require "bundler/setup"
require "trollop"
require "byebug"
require_relative "../model"

options = Trollop::options do
  banner <<EOS
Usage: #{$0} [options]
List files, directories, or tags in the database.

Tags are sorted most recent first so it's easy to look through
them and fix typos with "tag rename".
EOS
  opt :files, "List files in the database, sorted"
  opt :directories, "List directories in the database, sorted"
  opt :tags, "List tags in the database, most recent first"
  conflicts :files, :directories, :tags
end

case
when options.files
  Photo.map do |photo|
    photo.filename
  end.sort.each do |filename|
    puts filename
  end
when options.directories
  Photo.distinct.select(:directory).order(:directory).each do |photo|
    puts photo.directory
  end
when options.tags
  Tag.order(Sequel.desc(:created_at)).each do |tag|
    puts "%-20s %s" % [tag.tag, tag.created_at]
  end
end
