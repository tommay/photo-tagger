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
  banner "Usage: #{$0} [options] file|directory..."
  opt :recurse, "Recurse into directories"
end

process_args(ARGV, options.recurse) do |filename|
  Exporter.export_to_sidecar(filename)
end
