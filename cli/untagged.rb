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
  untagged(filename, options.recurse, options.directories)
end
