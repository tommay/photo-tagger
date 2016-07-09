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
  opt :verbose, "Show files being purged"
  opt :dryrun, "Dry run: see what would be purged (implies -v)",
    short: "n", long: "dry-run"
  opt :recurse, "Purge subdirectories too"
  opt :force, "Force removal even if file exists"
end

directory = ARGV[0]
begin
  directory = Pathname.new(directory).realpath.to_s
rescue Errno::ENOENT => ex
  # Directory doesn't exist in the filesystem, assume it's been
  # entered correctly.
end

if options.recurse
  Photo.all(:directory.like => File.join(directory, "%"))
else
  Photo.all(directory: directory)
end.each do |photo|
  if options.force || !File.exist?(photo.filename)
    if options.verbose || options.dryrun
      puts photo.filename
    end
    if !options.dryrun
      # This photo was fetched as part of a collection, so destroy is
      # slow because when we call .photo_sets DM anticipates that
      # we're going to need the photo_sets for all the photos and
      # loads them all.  This might not be so bad if it remembered
      # they were loaded, but it loads them all for each destory.
      # There is a collection_for_self method but it's private and
      # should be avoided.  So use first to get a Photo with no
      # associated collection, and destroy it without distraction.
      Photo.get(photo.id).destroy
    end
  end
end
