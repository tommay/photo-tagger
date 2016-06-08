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
  property :sha1, String, length: 28, required: true, index: :sha1
  property :filedate, DateTime, required: true # Date file was modified.
  property :created_at, DateTime, required: true # Date this row was updated.

  has n, :tags, through: Resource

  # XXX can this cascade automatically?  XXX This is craxy.  This
  # isn't even called unless there are no constraints blocking the
  # destroy, so photo_tags must be deleted manually ahead of time.
  # before :destroy do
  #   photo_tags.each(&:destroy)
  # end
  def destroy
    # This is horrible.  Instead of cascade deleting the photo_tags, I
    # have to delete them manually then reload otherwise dm thinks
    # there are still photo_tags that will be left hanging.
    # XXX DM isn't setting up the schema with foreign keys, WTF?
    photo_tags.each(&:destroy)
    reload
    super
  end

  def self.find_or_create(filename)
    photo = find_or_new(filename)
    if photo.new?
      photo.filedate = File.mtime(photo.filename)
      photo.created_at = Time.now

      pixbuf = Gdk::Pixbuf.new(file: filename)
      photo.sha1 = Base64.strict_encode64(Digest::SHA1.digest(pixbuf.pixels))

      photo.save
    end
    photo
  end

  def self.find_or_new(filename)
    realpath = Pathname.new(filename).realpath
    directory = realpath.dirname.to_s
    basename = realpath.basename.to_s

    first_or_new(directory: directory, basename: basename)
  end

  def filename
    File.join(directory, basename)
  end

  def identical
    Photo.all(sha1: self.sha1).select{|x| x.id != self.id}
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

# Throw exceptions instead of silently returning false.
#
DataMapper::Model.raise_on_save_failure = true

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
