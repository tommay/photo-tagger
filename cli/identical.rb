#!/usr/bin/env ruby

require "bundler/setup"
require "trollop"
require "pathname"
require "byebug"
require_relative "helpers"
require_relative "../importer"
require_relative "../model"

# identical file
#   List all the databased files identical to filename.

options = Trollop::options do
  banner <<EOS
Usage: #{$0} [options] file|directory
List all databases files identical to filename.
EOS
  opt :recurse, "Recurse into directories"
end

process_args(ARGV, options.recurse) do |filename|
  begin
    photo = Importer.find_or_import_from_file(
      filename, copy_tags: options.copy, purge_identical_images: options.purge,
      force_purge: options.force)
    identical = photo.identical
    if !identical.empty?
      puts photo.filename
      photo.identical.each do |identical|
        puts "  #{identical.filename}"
      end
    end
  rescue => ex
    puts "error: #{filename}: #{ex}"
  end
end
