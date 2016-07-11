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

# Is there a way to do ths that makes SQL do all the work and just
# return the tags with no photos?  That's a job for an outer join and
# the word "outer" doesn't appear in the source.

Tag.all.each do |tag|
  # This does one big select on photo_tags with the entire list of tag_ids.
  # At least the tags get deleted without much extra work (only checking
  # ithe contraint that they have no associated photos) which is surprising.
  if tag.photo_tags.empty?
    if options.destroy
      tag.destroy
    else
      puts tag.tag
    end
  end
end

# SELECT * FROM tags
#   OUTER JOIN tag_photos ON tag_photos.tag_id = tags.tag_id
#   WHERE tag_photos.tag_id IS NULL;
