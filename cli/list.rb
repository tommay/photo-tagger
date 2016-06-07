#!/usr/bin/env ruby

require "bundler/setup"
require "optparse"
require "pathname"
require "byebug"
require_relative "../model"

# list [-d|-f]
#   -f list files in the database
#   -d list directories in the database

opt_files = false
opt_directories = true

OptionParser.new do |opts|
  opts.banner = "Usage: $0 [options]"

  opts.on("-f", "List files") do
    opt_files = true
    opt_directories = false
  end

  opts.on("-d", "List directories") do
    opt_files = false
    opt_directories = true
  end

  opts.on("-h", "--help", "Print this help") do
    puts opts
    exit
  end
end.parse!

case
when opt_files
  Photo.all.each do |photo|
    puts "#{photo.filename}"
  end
when opt_directories
  Photo.all(:fields => [:directory], :unique => true, :order => [:directory.asc]).each do |photo|
    puts "#{photo.directory}"
  end
end
