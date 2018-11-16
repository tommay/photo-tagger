#!/usr/bin/env ruby

require "bundler/setup"
require "optimist"
require "byebug"

require_relative "../model"
require_relative "../files"

p = Optimist::Parser.new do
  banner <<EOS
Usage: #{$0} old new
Rename a tag from old to new.  Useful for fixing typos.

This does the right thing whether or not new tag already exists.
EOS
end

opts = Optimist::with_standard_exception_handling(p) do
  p.parse(ARGV).tap do |o|
    raise Optimist::HelpNeeded if ARGV.size != 2
  end
end

old_name = ARGV.shift
new_name = ARGV.shift

old_tag = Tag[tag: old_name]
if !old_tag
  puts "tag not found: #{old_name}"
  exit 1
end

new_tag = Tag[tag: new_name]
if !new_tag
  # No tag with the new name, so just change the old tag to the new name.
  old_tag.tag = new_name
  old_tag.save
else
  Photo.db.transaction do
    # Add new_tag to old_tag's photos.
    old_tag.photos.each do |photo|
      photo.add_tag(new_tag)
    end
    old_tag.destroy
  end
end
