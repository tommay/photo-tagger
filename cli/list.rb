#!/usr/bin/env ruby

require "bundler/setup"
require "optimist"
require "byebug"
require_relative "../model"
require_relative "helpers"

options = Optimist::options do
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
  opt :created, "Order files/directories by (database) creation time, most recent first"
end

case
when options.files
  if options.created
    Photo.order(Sequel.desc(:created_at)).each do |photo|
      puts photo.filename
    end
  else
    Photo.map do |photo|
      photo.filename
    end.sort.each do |filename|
      puts filename
    end
  end
when options.directories
  if options.created
    seen = {}
    Photo.order(Sequel.desc(:created_at)).each do |photo|
      if !seen[photo.directory]
        puts photo.directory
        seen[photo.directory] = true
      end
    end
  else
    Photo.distinct.select(:directory).order(:directory).each do |photo|
      puts photo.directory
    end
  end
when options.tags
  Tag.order(Sequel.desc(:created_at)).each do |tag|
    puts "%-20s %s" % [tag.tag, tag.created_at]
  end
end
