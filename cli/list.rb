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
  opt :created, "Order files/directories by (database) creation time, most recent first"
end

# If the STDOUT pipe is closed, either via ^C or something simple like piping
# into head, then puts will raise Errno::EPIPE and if it's called in
# a Sequel #each block then Sequel will handle it and barf all over the
# place.  So just handle it here and exit relatively cleanly.

def safe_puts(*args)
  begin
    puts(*args)
  rescue Errno::EPIPE
    exit(1)
  end
end

case
when options.files
  if options.created
    Photo.order(Sequel.desc(:created_at)).each do |photo|
      safe_puts photo.filename
    end
  else
    Photo.map do |photo|
      photo.filename
    end.sort.each do |filename|
      safe_puts filename
    end
  end
when options.directories
  if options.created
    seen = {}
    Photo.order(Sequel.desc(:created_at)).each do |photo|
      if !seen[photo.directory]
        safe_puts photo.directory
        seen[photo.directory] = true
      end
    end
  else
    Photo.distinct.select(:directory).order(:directory).each do |photo|
      safe_puts photo.directory
    end
  end
when options.tags
  Tag.order(Sequel.desc(:created_at)).each do |tag|
    safe_puts "%-20s %s" % [tag.tag, tag.created_at]
  end
end
