#!/usr/bin/env ruby

require "bundler/setup"
require "optimist"
require "byebug"
require_relative "../model"
require_relative "helpers"

# unused [-d]
#   List or delete unused tags.
#   -d delete unused tags.

options = Optimist::options do
  banner <<EOS
Usage: #{$0} [options]
List or delete unused tags.
EOS
  # Can't use :delete as the long name because options is a Hash that
  # already has #delete.
  opt :destroy, "Delete unused tags", long: :delete, short: :d
end

Tag.left_join(:photos_tags, :tag_id => :id)
    .where(Sequel[:photos_tags][:tag_id] => nil).each do |tag|
  if options.destroy
    tag.destroy
  else
    puts tag.tag
  end
end
