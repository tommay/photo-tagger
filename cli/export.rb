#!/usr/bin/env ruby

require "bundler/setup"
require "trollop"
require "byebug"
require_relative "../files"
require_relative "../exporter"

# export *.jpg
#   If there's a matching image file by name, then export its tags
#   to an xmp sidecar file, adding to any existing tags (?).

options = Trollop::options do
  banner "Usage: #{$0} [options] file|directory..."
  opt :recurse, "Recurse into directories"
end

def export(filename, options)
  Files.image_files(filename, options.recurse).each do |file|
    Exporter.export_to_sidecar(file)
  end
end

ARGV.each do |filename|
  export(filename, options)
end
