#!/usr/bin/env ruby

require "bundler/setup"
require "trollop"
require "fileutils"
require "byebug"

options = Trollop::options do
  banner "Usage: #{$0} directory..."
end

def clean(directory)
  Dir.glob(File.join(directory, "**", ".deleted")) do |deleted|
    FileUtils.remove_dir(deleted)
  end
  %x{tag purge -r #{directory}}
  %x{find "#{directory}" "(" -type d -empty -o -name "*.bak" ")" -delete}
end

ARGV.each do |directory|
  clean(directory)
end

