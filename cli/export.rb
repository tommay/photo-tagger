#!/usr/bin/env ruby

require "bundler/setup"
require "trollop"
require "byebug"
require_relative "helpers"
require_relative "../exporter"

# export *.jpg
#   If there's a matching image file by name, then export its tags
#   to an xmp sidecar file, adding to any existing tags (?).

options = Trollop::options do
  banner <<EOS
Usage: #{$0} [options] file|directory...
Export from database to .xmp sidecar files: sha1, tags, rating.

If a sidecar file exists, information is added to it.

If there is no database entry for a file, do nothing.
Existing sidecar files are backed up as .xmp.0.
EOS
  opt :recurse, "Recurse into directories"
end

process_args(ARGV, options.recurse) do |filename|
  Exporter.export_to_sidecar(filename)
end
