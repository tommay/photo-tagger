#!/usr/bin/env ruby

require "bundler/setup"
require "trollop"
require "byebug"

require_relative "../model"
require_relative "../files"

options = Trollop::options do
  banner "Usage: #{$0} [options] file|directory..."
  opt :add, "Add tag to images", type: String, multi: true
  opt :remove, "Add tag to images", short: :R, type: String, multi: true
  opt :recurse, "Recurse into directories"
end

def tag(filename, add, remove)
  photo = Photo.find_or_create(filename)

  add.each do |tag|
    photo.add_tag(tag)
  end

  remove.each do |tag|
    photo.remove_tag(tag)
  end
end

ARGV.each do |filename|
  Files.image_files(filename, options.recurse).each do |file|
    tag(file, options.add, options.remove)
  end
end
