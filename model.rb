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
  property :directory, String, length: 500, required: true, unique_index: :name
  property :filename, String, length: 500, required: true, unique_index: :name
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

Tag.create(
  tag: "flower"
).save
tag = Tag.first(tag: "flower")

photo = Photo.create(
  directory: "/photo",
  filename: "one",
  filedate: Time.now,
  created_at: Time.now
)
photo.save
photo.tags << tag
photo.save

photo = Photo.create(
  directory: "/photo",
  filename: "two",
  filedate: Time.now,
  created_at: Time.now
)
photo.save
photo.tags << tag
photo.save

photo.tags

Photo.all(directory: "/photo").tags
# SELECT "tags"."id", "tags"."tag"
#   FROM "tags"
#   INNER JOIN "photo_tags"
#     ON "tags"."id" = "photo_tags"."tag_id"
#   INNER JOIN "photos"
#     ON "photo_tags"."photo_id" = "photos"."id"
#   WHERE "photo_tags"."photo_id" IN
#    (SELECT "id" FROM "photos" WHERE "directory" = '/photo')
#   GROUP BY "tags"."id", "tags"."tag"
#   ORDER BY "tags"."id"

# SELECT tags.id, tags.tag
#   FROM tags
#   JOIN photo_tags
#     ON photo_tags.tag_id = tags.id
#   JOIN photos
#     ON photos.id = photo_tags.photo_id
#   WHERE photo_tags.photo_id IN
#    (SELECT id FROM photos WHERE directory = '/photo')
#   GROUP BY tags.id, tags.tag
#   ORDER BY tags.id



