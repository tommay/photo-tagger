#!/usr/bin/env ruby

require "bundler/setup"
require "optparse"
require "byebug"
require_relative "../model"
require_relative "../files"

# import [-r] .|*.xmp
#   If there's a matching image file by name, then add it to the
#   database if it's not there already.  Either add its tags to the
#   database, or replace its tags.
#   -r to recurse into directories.

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

def import(filename, recurse)
  case
  when File.directory?(filename)
    filenames = Dir[File.join(filename, "*.xmp")]
    filenames.each do |filename|
      import(filename, recurse)
    end
  when File.file?(filename)
    import_from_file(filename)
  end
end

def import_from_file(filename)
  # Fetch or create a database entry.

  image_filename = filename.sub(/\.xmp$/, "")
  photo = Photo.find_or_create(image_filename)

  # Read and parse the xmp and extract the tags.  This appends tags
  # without replacing the existing tags.

  xmp = Nokogiri::XML(File.read(filename))
  namespaces = {
    "dc" => "http://purl.org/dc/elements/1.1/",
    "rdf" => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
  }

  xmp.css("dc|subject rdf|li", namespaces).each do |tag|
    photo.add_tag(tag.text)
  end
end

ARGV.each do |filename|
  import(filename, opt_recurse)
end
