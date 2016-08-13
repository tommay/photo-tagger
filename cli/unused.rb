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

Tag.left_join(:photos_tags, :tag_id => :id).where(photos_tags__tag_id: nil).each do |tag|
  if options.destroy
    tag.destroy
  else
    puts tag.tag
  end
end
