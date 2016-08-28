#!/usr/bin/env ruby

require "bundler/setup"
require "trollop"
require "byebug"
require_relative "helpers"
require_relative "../importer"

# import [-r] dir|*.jpg
#   Add images to the database by filename if they don't already exist.
#   If any existing images have the same sha1, their tags are added.
#   Read xmp sidecar files and add the tags to the database.
#   -r to recurse into directories.
#   XXX might want a way to replace tags instead of add.

options = Trollop::options do
  banner "Usage: #{$0} [options] file|directory..."
  opt :copy, "Copy tags from existing identical images"
  opt :purge, "Purge identical images that no longer exist"
  opt :force, "Purge identical images even if they exist"
  opt :recurse, "Recurse into directories"
end

process_args(ARGV, options.recurse) do |filename|
  begin
    Importer.find_or_import_from_file(
      filename, copy_tags: options.copy, purge_identical_images: options.purge,
      force_purge: options.force)
  rescue => ex
    puts "error: #{filename}: #{ex}"
  end
end
