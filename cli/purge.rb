#!/usr/bin/env ruby

require "bundler/setup"
require "trollop"
require "pathname"
require "byebug"
require_relative "../model"

options = Trollop::options do
  banner <<EOS
Usage: #{$0} [options] directory
Remove photos from the database with no corresponding file.  Only
photos from  XXX

If a directory is given only photos from that directory are removed.
EOS
  opt :recurse, "Purge subdirectories too"
  opt :force, "Force removal from database even if file exists"
  opt :verbose, "Show files being purged"
  opt :dryrun, "Dry run: see what would be purged (implies -v)",
    short: "n", long: "dry-run"
end

photos =
  begin
    if File.file?(ARGV[0])
      Array(Photo.find(ARGV[0]))
    else
      directory =
        begin
          Pathname.new(ARGV[0]).realpath.to_s
        rescue Errno::ENOENT => ex
          # Directory doesn't exist in the filesystem, assume it's been
          # entered correctly.
          ARGV[0]
        end

      if options.recurse
        Photo.where(Sequel.like(:directory, File.join(directory, "%")))
      else
        Photo.where(directory: directory)
      end
    end
  end

photos.each do |photo|
  if options.force || !File.exist?(photo.filename)
    if options.verbose || options.dryrun
      puts photo.filename
    end
    if !options.dryrun
      photo.destroy
    end
  end
end
