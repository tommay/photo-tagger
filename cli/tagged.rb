#!/usr/bin/env ruby

require "bundler/setup"
require "trollop"
require "byebug"
require_relative "../model"

options = Trollop::options do
  banner "Usage: #{$0} tag..."
  opt :nul, "Nul-terminate output filenames"
  opt :null, "Same as --nul"
  opt :tags, "Show files' tags"
  opt :ugly, "Show files' tags in tag -a ... format"
  conflicts :nul, :tags, :ugly
  conflicts :null, :tags, :ugly
  stop_on_unknown
end

terminator = (options.nul || options.null) ? "\0" : "\n"

photos = ARGV.map do |tag|
  tag =~ /^(-?)(.*)/
  [$1, Tag.all(:tag.like => $2).photos]
end

_, photos = photos.reduce do |(_, memo), (type, photos)|
  if type == "-"
    [nil, memo - photos]
  else
    [nil, memo & photos]
  end
end

def quote(s)
  s.gsub(/\\/, "\\\\")
  s.gsub(/"/, "\\\"")
  s.gsub(/\$/, "\\$")
  "\"#{s}\""
end

if options.tags || options.ugly
  photos = photos.map do |photo|
    [photo.filename, photo.tags.map{|t|t.tag}.sort]
  end

  photos = photos.sort_by{|p| p[0]}

  photos.each do |photo|
    if options.ugly
      photo[1].each { |t| print " -a #{quote(t)}" }
      puts " #{quote(photo[0])}"
    else
      puts "#{photo[0]}: #{photo[1].join(", ")}"
    end
  end
else
  filenames = photos.map do |photo|
    photo.filename
  end

  filenames.sort.each do |filename|
    print "#{filename}#{terminator}"
  end
end
