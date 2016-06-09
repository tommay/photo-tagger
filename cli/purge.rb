#!/usr/bin/env ruby

require "bundler/setup"
require "trollop"
require "pathname"
require "byebug"
require_relative "../model"

# purge [-f] [-r] directory
#   For all the databased images in dir, or all images, if the image
#   doesn't exist in the filesystem then delete it from the database.
#   -f to delete from the database whether the image exists or not.

options = Trollop::options do
  banner "Usage: #{$0} [options] file|directory..."
  opt :force, "Force removal even if file exists"
end

directory = ARGV[0]
begin
  directory = Pathname.new(directory).realpath.to_s
rescue Errno::ENOENT => ex
  # Directory doesn't exist in the filesystem, assume it's been
  # entered correctly.
end

Photo.all(directory: directory).each do |photo|
  if options.force || !File.exist?(photo.filename)
    photo.destroy
  end
end
