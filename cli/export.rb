#!/usr/bin/env ruby

require "bundler/setup"
require "optimist"
require "byebug"
require_relative "helpers"
require_relative "../exporter"

# export *.jpg
#   If there's a matching image file by name, then export its tags
#   to an xmp sidecar file, adding to any existing tags (?).
#   Existing xmp files will not be overwritten unless the photo's
#   updated_at time is more recent than the file's modification time
#   or -f/--force is used.

options = Optimist::options do
  banner <<EOS
Usage: #{$0} [options] file|directory...
Export from database to .xmp sidecar files: sha1, tags, rating.

Existing xmp files will not be overwritten unless the photo's
updated_at time is more recent than the file's modification time or
-f/--force is used.

Data can be merged into existing xmp files with -a/--add.

Existing sidecar files are backed up as .xmp.bak if they would be overwritten.

If there is no database entry for a file, do nothing.
EOS
  opt :recurse, "Recurse into directories"
  opt :force, "Overwrite existing xmp sidecar files"
  # This should be called "merge" but that silently collides with the
  # options Hash#merge method because Optimist uses method missing and
  # #merge is not missing.
  opt :add, "Add/Merge data into a possibly existing xmp file"
end

process_args(ARGV, options.recurse) do |filename|
  Exporter.export_to_sidecar(filename,
    merge: options.add, force: options.force)
end
