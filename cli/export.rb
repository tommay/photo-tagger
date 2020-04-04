#!/usr/bin/env ruby

require "bundler/setup"
require "optimist"
require "byebug"
require_relative "helpers"
require_relative "../exporter"

# export *.jpg
#   If there's a matching image file by name, then export its tags
#   to an xmp sidecar file, adding to any existing tags (?).

options = Optimist::options do
  banner <<EOS
Usage: #{$0} [options] file|directory...
Export from database to .xmp sidecar files: sha1, tags, rating.

Existing sidecar files can be overwritten, or data can be merged into it.
Existing sidecar files are backed up as .xmp.0.

If there is no database entry for a file, do nothing.
EOS
  opt :recurse, "Recurse into directories"
  # This should be called "merge" but that silently collides with the
  # options Hash#merge method because Optimist uses method missing and
  # #merge is not missing.
  opt :add, "Add/Merge data into a possibly existing xmp file"
end

process_args(ARGV, options.recurse) do |filename|
  Exporter.export_to_sidecar(filename, merge: options.add)
end
