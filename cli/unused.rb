#!/usr/bin/env ruby

require "bundler/setup"
require "trollop"
require "byebug"
require_relative "../model"

# unused [-d]
#   List or delete unused tags.
#   -d delete unused tags.

options = Trollop::options do
  banner "Usage: #{$0} [options]"
  # Can't use :delete as the long name because options is a Hash that
  # already has #delete.
  opt :destroy, "Delete unused tags", long: :delete, short: :d
end

# Is there a wat to do ths that makes SQLdo all the work and just
# return the tags with no images?

Tag.all.each do |tag|
  # if tag.photos.empty?  # Yuck.  Not sure if this is better; it
  # selects the entire photo_tag table.
  if tag.photo_tags.empty?
    if options.destroy
      tag.destroy
    else
      puts tag.tag
    end
  end
end
