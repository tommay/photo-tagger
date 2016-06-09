#!/usr/bin/env ruby

require "bundler/setup"
require "trollop"
require "byebug"
require_relative "../model"

# list [-d|-f]
#   -f list files in the database
#   -d list directories in the database

options = Trollop::options do
  banner "Usage: #{$0} [options]"
  opt :files, "List files in the database"
  opt :directories, "List directories in the database"
end

case
when options.files
  Photo.all.each do |photo|
    puts "#{photo.filename}"
  end
when options.directories
  Photo.all(:fields => [:directory], :unique => true, :order => [:directory.asc]).each do |photo|
    puts "#{photo.directory}"
  end
end
