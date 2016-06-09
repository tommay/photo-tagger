#!/usr/bin/env ruby

require "bundler/setup"
require "optparse"
require "byebug"
require_relative "../files"
require_relative "../importer"

recurse = false
list_directories = false

OptionParser.new do |opts|
  opts.banner = "Usage: $0 [options] [directory...]"

  opts.on("-d", "List directories with untagged files") do
    list_directories = true
  end

  opts.on("-r", "Recurse directories") do
    recurse = true
  end

  opts.on("-h", "--help", "Print this help") do
    puts opts
    exit
  end
end.parse!

@directories = {}

def untagged(filename, recurse, list_directories)
  Files.image_files(filename, recurse).each do |file|
    photo = Importer.find_or_import_from_file(
      file, copy_tags: true, purge_identical_images: false)
    if photo.tags.empty?
      if list_directories
        if !@directories[photo.directory]
          @directories[photo.directory] = true
          puts photo.directory
        end
      else
        puts photo.filename
      end
    end
  end
end

ARGV.each do |filename|
  untagged(filename, recurse, list_directories)
end
