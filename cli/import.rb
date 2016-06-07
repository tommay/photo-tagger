#!/usr/bin/env ruby

require "bundler/setup"
require "optparse"
require "byebug"
require_relative "../model"
require_relative "../files"

# import [-r] dir|*.jpg
#   Add images to the database by filename if they don't already exit.
#   Read xmp sidecar files and add the tags to the database.
#   -r to recurse into directories.
#   XXX might want a way to replace tags instead of add.

opt_recurse = false

OptionParser.new do |opts|
  opts.banner = "Usage: $0 [options] [directory...]"

  opts.on("-r", "Recurse directories") do
    opt_recurse = true
  end

  opts.on("-h", "--help", "Print this help") do
    puts opts
    exit
  end
end.parse!

def import(filename, recurse:, top:)
  case
  when (top || recurse) && File.directory?(filename)
    Dir[File.join(filename, "*")].each do |f|
      import(f, recurse: recurse, top: false)
    end
  when Files.image_file?(filename)
    import_from_file(filename)
  end
end

def import_from_file(filename)
  # Fetch or create a database entry.

  photo = Photo.find_or_create(filename)

  # If there's an xmp sidecar file, read it and extract the tags.
  # XXX This appends tags without replacing the existing tags.

  xmp_filename = "#{filename}.xmp"
  if File.exist?(xmp_filename)
    xmp = Nokogiri::XML(File.read("#{filename}.xmp"))
    namespaces = {
      "dc" => "http://purl.org/dc/elements/1.1/",
      "rdf" => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
    }
    xmp.css("dc|subject rdf|li", namespaces).each do |tag|
      photo.add_tag(tag.text)
    end
  end
end

ARGV.each do |filename|
  import(filename, recurse: opt_recurse, top: true)
end
