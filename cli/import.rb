#!/usr/bin/env ruby

require "bundler/setup"
require "optparse"
require "byebug"
require_relative "../files"
require_relative "../importer"

# import [-r] dir|*.jpg
#   Add images to the database by filename if they don't already exist.
#   If any existing images have the same sha1, their tags are added.
#   Read xmp sidecar files and add the tags to the database.
#   -r to recurse into directories.
#   XXX might want a way to replace tags instead of add.

options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: $0 [options] [directory...]"

  opts.on("-c", "Copy tags from identical images") do
    options[:copy_tags] = true
  end

  opts.on("-p", "Purge identical images that no longer exist") do
    options[:purge_identical_images] = true
  end

  opts.on("-r", "Recurse directories") do
    options[:recurse] = true
  end

  opts.on("-h", "--help", "Print this help") do
    puts opts
    exit
  end
end.parse!

def import(filename, options)
  Files.image_files(filename, options[:recurse]).each do |file|
    Importer.find_or_import_from_file(file, options)
  end
end

ARGV.each do |filename|
  import(filename, options)
end
