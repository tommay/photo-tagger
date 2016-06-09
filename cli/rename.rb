#!/usr/bin/env ruby

require "bundler/setup"
require "trollop"
require "byebug"

require_relative "../model"
require_relative "../files"

p = Trollop::Parser.new do
  banner "Usage: #{$0} old new"
end

opts = Trollop::with_standard_exception_handling(p) do
  p.parse(ARGV).tap do |o|
    raise Trollop::HelpNeeded if ARGV.size != 2
  end
end

old_name = ARGV.shift
new_name = ARGV.shift

old_tag = Tag.first(tag: old_name)
if !old_tag
  puts "tag not found: #{old_name}"
  exit 1
end

new_tag = Tag.first(tag: new_name)
if !new_tag
  # No tag with the new name, so just change the old tag to the new name.
  old_tag.tag = new_name
  old_tag.save
else
  # Add new_tag to old_tag's photos.
  old_tag.photos.each do |photo|
    photo.tags << new_tag
    photo.save
 end
  # Destroy old_tag.
  old_tag.photos.clear
  old_tag.save
  old_tag.destroy
end
