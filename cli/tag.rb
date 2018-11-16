#!/usr/bin/env ruby

require "bundler/setup"
require "optimist"
require "byebug"

require_relative "helpers"
require_relative "../importer"

options = Optimist::options do
  banner "Usage: #{$0} [options] file|directory..."
  opt :add, "Add tag to images", type: String, multi: true
  opt :remove, "Remove tag from images", short: :R, type: String, multi: true
  opt :recurse, "Recurse into directories"
end

process_args(ARGV, options.recurse) do |filename|
  photo = Importer.find_or_import_from_file(
    filename, copy_tags_and_rating: true, purge_identical_images: false,
    force_purge: false)

  Photo.db.transaction do
    options.add.each do |tag|
      photo.add_tag(tag)
    end

    options.remove.each do |tag|
      photo.remove_tag(tag)
    end
  end
end
