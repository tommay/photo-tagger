#!/usr/bin/env ruby

require "bundler/setup"
require "optparse"
require "byebug"
require_relative "../model"
require_relative "../files"
require_relative "../xmp"

# import [-r] dir|*.jpg
#   Add images to the database by filename if they don't already exist.
#   If any existing images have the same sha1, their tags are added.
#   Read xmp sidecar files and add the tags to the database.
#   -r to recurse into directories.
#   XXX might want a way to replace tags instead of add.

options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: $0 [options] [directory...]"

  opts.on("-c", "Copy tags from identical images") do
    options[:copy_tags] = true
  end

  opts.on("-p", "Purge identical images that no longer exist") do
    options[:purge_identical_images] = true
  end

  opts.on("-r", "Recurse directories") do
    options[:recurse] = true
  end

  opts.on("-h", "--help", "Print this help") do
    puts opts
    exit
  end
end.parse!

def import(filename, options, top)
  case
  when (top || recurse) && File.directory?(filename)
    Dir[File.join(filename, "*")].each do |f|
      import(f, options, false)
    end
  when Files.image_file?(filename)
    import_from_file(filename, options)
  end
end

def import_from_file(filename, options)
  # Fetch or create a database entry.

  photo = Photo.find_or_create(filename)

  # If requested, add tags from existing identical images.
  # XXX this should be the default.

  if options[:copy_tags]
    photo.each_identical_to(photo) do |identical|
      photo.tags += identical.tags
    end
  end

  # If there's an xmp sidecar file, read it and extract the tags.
  # XXX This appends tags without replacing the existing tags.

  xmp_filename = "#{filename}.xmp"
  if File.exist?(xmp_filename)
    xmp = Xmp.new(File.read(xmp_filename))
    xmp.get_tags.each do |tag|
      photo.add_tag(tag)
    end
  end

  photo.save

  # If requested, purge identical images that no longer exist.

  if options[:purge_identical_images]
    photo.each_identical_to(photo) do |identical|
      if !File.exist?(identical.filename)
        identical.destroy
      end
    end
  end
end

ARGV.each do |filename|
  import(filename, options, true)
end
