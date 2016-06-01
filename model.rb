#!/usr/bin/env ruby

require "data_mapper"
require "byebug"

# If you want the logs displayed you have to do this before the call to setup
DataMapper::Logger.new($stdout, :debug)

# An in-memory Sqlite3 connection:
#DataMapper.setup(:default, "sqlite::memory:")

# A Sqlite3 connection to a persistent database
DataMapper.setup(:default, "sqlite:///home/tom/viewer/viewer.db")

# XXX Use Integer instead of DateTime?

class Photo
  include DataMapper::Resource

  property :id, Serial
  property :directory, String, length: 500, required: true, unique_index: :name
  property :basename, String, length: 500, required: true, unique_index: :name
  property :filedate, DateTime, required: true # Date file was modified.
  property :created_at, DateTime, required: true # Date this row was updated.

  has n, :tags, through: Resource

  def self.find_or_create(filename)
    absolute = File.absolute_path(filename)
    directory = File.dirname(absolute)
    basename = File.basename(absolute)

    photo = first(directory: directory, basename: basename)
    if !photo
      filedate = File.mtime(absolute)
      photo = Photo.create(directory: directory, basename: basename,
                           filedate: filedate, created_at: Time.now)
      photo.save
    end
    photo
  end

  def filename
    File.join(directory, basename)
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

DataMapper.finalize
