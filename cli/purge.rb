#!/usr/bin/env ruby

require "bundler/setup"
require "optparse"
require "pathname"
require "byebug"
require_relative "../model"

# purge [-f] [-r] directory
#   For all the databased images in dir, or all images, if the image
#   doesn't exist in the filesystem then delete it from the database.
#   -r to find and operate on all directories in the db that match
#      recursively.
#   -f to delete from the database whether the image exists or not.

opt_recurse = false
opt_force = false

OptionParser.new do |opts|
  opts.banner = "Usage: $0 [options] [directory...]"

  opts.on("-r", "Recurse directories") do
    opt_recurse = true
  end

  opts.on("-f", "Force removal even if file exists") do
    opt_force = true
  end

  opts.on("-h", "--help", "Print this help") do
    puts opts
    exit
  end
end.parse!

directory = ARGV[0]
begin
  directory = Pathname.new(directory).realpath.to_s
rescue Errno::ENOENT => ex
  # Directory doesn't exist in the filesystem, assume it's been
  # entered correctly.
end

Photo.all(directory: directory).each do |photo|
  if opt_force || !File.exist?(photo.filename)
    photo.destroy
  end
end
