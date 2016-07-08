#!/usr/bin/env ruby

require "bundler/setup"
require "trollop"
require "byebug"
require_relative "../files"
require_relative "../importer"

options = Trollop::options do
  banner "Usage: #{$0} [options] file|directory..."
  opt :force, "Change rating if already rated"
  opt :recurse, "Recurse into directories"
end

rating = ARGV.shift.to_i

def rate(filename, rating, options)
  Files.image_files(filename, options.recurse).each do |file|
    begin
      photo =
        Importer.find_or_import_from_file(
        file, copy_tags: true, purge_identical_images: false,
        force_purge: false)
      if !photo.rating || options.force
        photo.rating = rating
        photo.save
      end
    rescue => ex
      puts "error: #{file}: #{ex}"
    end
  end
end

ARGV.each do |filename|
  rate(filename, rating, options)
end
