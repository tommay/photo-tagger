#!/usr/bin/env ruby

require "bundler/setup"
require "trollop"
require "byebug"
require_relative "helpers"
require_relative "../importer"

options = Trollop::options do
  banner "Usage: #{$0} [options] rating file|directory..."
  opt :force, "Change rating if already rated"
  opt :recurse, "Recurse into directories"
end

rating = ARGV.shift.to_i

process_args(ARGV, options.recurse) do |filename|
  begin
    photo =
      Importer.find_or_import_from_file(
      filename, copy_tags: true, purge_identical_images: false,
      force_purge: false)
    if !photo.rating || options.force
      photo.rating = rating
      photo.save
    end
  rescue => ex
    puts "error: #{filename}: #{ex}"
  end
end
