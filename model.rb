#!/usr/bin/env ruby

require "data_mapper"
require "gtk3"
require "pathname"
require "digest"
require "base64"
require "byebug"

# XXX Use Integer instead of DateTime?

class Photo
  include DataMapper::Resource

  property :id, Serial
  property :directory, String, length: 500, required: true, unique_index: :name
  property :basename, String, length: 500, required: true, unique_index: :name
  property :sha1, String, length: 28, required: true, unique_index: :sha1
  property :filedate, DateTime, required: true # Date file was modified.
  property :created_at, DateTime, required: true # Date this row was updated.

  has n, :tags, through: Resource

  def self.find_or_create(filename)
    realpath = Pathname.new(filename).realpath
    directory = realpath.dirname.to_s
    basename = realpath.basename.to_s

    photo = first(directory: directory, basename: basename)
    if !photo
      filedate = File.mtime(realpath)

      pixbuf = Gdk::Pixbuf.new(file: filename)
      sha1 = Base64.strict_encode64(Digest::SHA1.digest(pixbuf.pixels))

      photo = Photo.create(directory: directory, basename: basename,
                           sha1: sha1,
                           filedate: filedate, created_at: Time.now)
      photo.save
    end
    photo
  end

  def filename
    File.join(directory, basename)
  end

  def add_tag(string)
    # XXX I think this is supposed to work, but it only works if the tag
    # doesn't exist in which case it creates the tag and links it, else
    # it does nothing.
    # self.tags.first_or_create(tag: string)
    # So do it the hard way.
    tag = Tag.first_or_create(tag: string)
    if !self.tags.include?(tag)
      self.tags << tag
      self.save
      true
    end
  end

  def remove_tag(string)
    tag = self.tags.first(tag: string)
    if tag
      self.tags.delete(tag)
      self.save
      true
    end
  end
end

class Tag
  include DataMapper::Resource

  property :id, Serial
  property :tag, String, length: 100, required: true, unique: true

  has n, :photos, through: Resource

  def self.for_directory(directory)
    Photo.all(directory: directory).tags
  end
end

class State
  include DataMapper::Resource

  property :id, Serial
  property :photo_id, Integer, required: true
end

DataMapper.finalize

db_file = "/home/tom/tagger/tags.db"

# If you want the logs displayed you have to do this before the call to setup
#
DataMapper::Logger.new($stdout, :debug)

# A Sqlite3 connection to a persistent database
#
DataMapper.setup(:default, "sqlite://#{db_file}")

# Create the file+schema if it doesn't exist.
#
if !File.exist?(db_file)
  DataMapper.auto_migrate!
end
