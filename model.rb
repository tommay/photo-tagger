#!/usr/bin/env ruby

require "data_mapper"

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

  has n, :phototags
  has n, :tags, through: :phototags
end

class Tag
  include DataMapper::Resource

  property :id, Serial          # An auto-increment integer key
  property :tag, String, length: 100, required: true, unique: true

  has n, :phototags
  has n, :photos, through: :phototags
end

class Phototag
  include DataMapper::Resource

  belongs_to :photo, key: true
  belongs_to :tag, key: true
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
