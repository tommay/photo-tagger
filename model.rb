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

  property :id,         Serial   # An auto-increment integer key
  property :filename, String, length: 4000, required: true, unique: true
  property :filedate, DateTime, required: true       # Date file was modified.
  property :created_at, DateTime, required: true # Date this row was updated.

  has n, :tags, through: Resource
end

class Tag
  include DataMapper::Resource

  property :id, Serial          # An auto-increment integer key
  property :tag, String, length: 100, required: true, unique: true

  has n, :photos, through: Resource
end

DataMapper.finalize

DataMapper.auto_migrate!
#DataMapper.auto_upgrade!

photo = Photo.create(
  filename: "/photo/one",
  filedate: Time.now,
  created_at: Time.now
)

tag = Tag.create(
  tag: "flower"
)
