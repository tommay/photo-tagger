#!/usr/bin/env ruby

require "bundler/setup"
require "optimist"
require "byebug"
require_relative "helpers"
require_relative "../importer"

options = Optimist::options do
  banner <<EOS
Add images to the database by filename if they don't already exist.
Also read xmp sidecar files and add tags and rating to the database.
XXX might want a way to replace tags instead of add.
EOS
  opt :recurse, "Recurse into directories"
  opt :copy, "Copy tags and rating from existing identical images"
  opt :purge, "Purge identical images that no longer exist"
  opt :force, "Purge identical images even if they exist"
end

process_args(ARGV, options.recurse) do |filename|
  begin
    Importer.find_or_import_from_file(
      filename, copy_tags_and_rating: options.copy,
      purge_identical_images: options.purge,
      force_purge: options.force)
  rescue => ex
    puts "error: #{filename}: #{ex}"
  end
end
