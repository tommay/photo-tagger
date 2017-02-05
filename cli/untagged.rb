#!/usr/bin/env ruby

require "bundler/setup"
require "trollop"
require "byebug"
require_relative "helpers"
require_relative "../importer"

options = Trollop::options do
  banner <<EOS
Usage: #{$0} [options] file|directory...
List untagged files, so they can be tagged.
EOS
  opt :recurse, "Recurse into directories"
  opt :directories, "List directories with untagged files"
end

directories = {}

process_args(ARGV, options.recurse) do |filename|
  if Photo.find_dataset(filename).phototags.count == 0
    if options.directories
      directory = File.dirname(filename)
      if !directories[directory]
        directories[directory] = true
        puts directory
      end
    else
      puts filename
    end
  end
end
