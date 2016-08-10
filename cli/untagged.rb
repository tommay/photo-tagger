#!/usr/bin/env ruby

require "bundler/setup"
require "trollop"
require "byebug"
require_relative "../files"
require_relative "../importer"

options = Trollop::options do
  banner "Usage: #{$0} [options] file|directory..."
  opt :directories, "List directories with untagged files"
  opt :recurse, "Recurse into directories"
end

@directories = {}

def untagged(filename, recurse, list_directories)
  Files.image_files(filename, recurse).each do |file|
    photo = Photo.find(file)
    # Performance is the same for photo.tags_dataset.count == 0.
    if !photo || photo.tags.empty?
      if list_directories
        directory = File.dirname(file)
        if !@directories[directory]
          @directories[directory] = true
          puts directory
        end
      else
        puts file
      end
    end
  end
end

ARGV.each do |filename|
  untagged(filename, options.recurse, options.directories)
end
