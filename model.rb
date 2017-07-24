#!/usr/bin/env ruby

require "sequel"
require "logger"
require "gtk3"                  # For Gdk::Pixbuf
require "pathname"
require "digest"
require "exiv2"
require "byebug"

require_relative "files"

module Model
  # This makes association datasets "chainable" which makes tagged.rb
  # comceptually simpler, more like data_mapper.

  Sequel::Model.plugin :dataset_associations

  def self.setup(file)
    # Whether we need to create the schema.

    need_schema = !File.exist?(file)

    # A Sqlite3 connection to a persistent database

    Sequel.connect(
      "sqlite:#{file}",
      logger: Logger.new(STDOUT).tap do |logger|
        logger.level = Logger::WARN
      end
    ).tap do |db|
      db.use_timestamp_timezones = true
      db.run("pragma journal_mode = truncate")

      if need_schema
        create_schema(db)
      end
    end
  end

  def self.create_schema(db)
    db.create_table :photos do
      primary_key :id
      column :directory, String, size: 500, null: false
      column :basename, String, size: 500, null: false
      column :sha1, String, size: 28, null: false
      column :filedate, DateTime, null: false # Date file was modified.
      column :taken_time, String, size: 100, null: true
      column :rating, Integer, null: true
      column :focal_length, Numeric, null: true
      column :focal_length_35mm, Numeric, null: true
      column :aperture, Numeric, null: true
      column :exposure_time, Numeric, null: true
      column :make, String, size: 100, null: true
      # This can't be called just "model" since Photo.model is "Photo".
      column :camera_model, String, size: 100, null: true
      column :protected, Boolean, null: false
      column :created_at, DateTime, null: false # Date this row was updated.

      unique [:directory, :basename]
      index :sha1
    end

    db.create_table :tags do
      primary_key :id
      column :tag, String, size: 100, null: false
      column :created_at, DateTime, null: false

      unique :tag
    end

    # The photos/tags join table, cf. create_join_table
    #
    db.create_table :photos_tags do
      column :photo_id, Integer, null: false
      column :tag_id, Integer, null: false

      primary_key [:photo_id, :tag_id]
      unique [:tag_id, :photo_id]

      foreign_key [:photo_id], :photos, on_delete: :cascade
      foreign_key [:tag_id], :tags, on_delete: :cascade
    end

    db.create_table :lasts do
      column :directory, String, size: 500, primary_key: true
      column :filename, String, size: 500, null: false
    end
  end
end

# Search up the directory tree from the current directory looking for
# a .taggerdb file to tell us what sqlite file to use.  If no
# .taggerdb is found, use tags,db in the current directory.  TAGGER_DB
# in the environment overrides this.

get_db = lambda do |dir|
  file = File.join(dir, ".taggerdb")
  if File.exist?(file)
    File.expand_path(File.read(file).chomp)
  else
    if dir == "/"
      dot_tagger = File.expand_path(File.join("~", ".tagger"))
      if !File.directory?(dot_tagger)
        Dir.mkdir(dot_tagger)
      end
      File.join(dot_tagger, "tags.db")
    else
      get_db.call(File.dirname(dir))
    end
  end
end

db_file = ENV["TAGGER_DB"] || get_db.call(Dir.pwd)

Model.setup(db_file)

class Photo < Sequel::Model
  many_to_many :tags
  one_to_many :phototags
  # Don't need this with on_delete cascade.
  plugin :association_dependencies, tags: :nullify

  def self.find_or_create(filename, &block)
    super(split_filename(filename)) do |photo|
      # Give the caller first chance to fill in values from xmp or
      # wherever.

      block&.call(photo)

      # Now set anything the caller didn't.

      photo.filedate ||= File.mtime(photo.filename)
      photo.created_at ||= Time.now

      ExifData.new(photo.filename).tap do |exif_data|
        photo.taken_time    ||= exif_data.get_taken_time
        photo.focal_length  ||= exif_data.get_real("Exif.Photo.FocalLength")
        photo.focal_length_35mm ||=
          exif_data.get_real("Exif.Photo.FocalLengthIn35mmFilm")
        photo.aperture      ||= exif_data.get_real("Exif.Photo.FNumber")
        photo.exposure_time ||= exif_data.get_real("Exif.Photo.ExposureTime")
        photo.make          ||= exif_data.get_string("Exif.Image.Make")
        photo.camera_model  ||= exif_data.get_string("Exif.Image.Model")
      end

      if !photo.sha1
        photo.set_sha1
      end
    end
  end

  def set_sha1
    self.sha1 = Photo.compute_sha1(self.filename)
  end

  def self.compute_sha1(filename)
    GC.start
    pixbuf = GdkPixbuf::Pixbuf.new(file: filename)	
    pixels = pixbuf.read_pixel_bytes
    row_width = pixbuf.width * pixbuf.n_channels * pixbuf.bits_per_sample / 8
    if row_width < pixbuf.rowstride
      # XXX It may be better to use pixels.slice each time through the loop.
      pixel_string = pixels.to_str
      stride = pixbuf.rowstride
      digest = Digest::SHA1.new
      0.upto(pixbuf.height - 1) do |row|
        digest << pixel_string[row * stride, row_width]
      end
      digest.base64digest
    else
      Digest::SHA1.base64digest(pixels)
    end
  end

  def self.find(filename)
    super(filename.is_a?(String) ? split_filename(filename) : filename)
  end

  def self.find_dataset(filename)
    where(split_filename(filename))
  end

  def self.split_filename(filename)
    realpath = Pathname.new(filename).realpath
    {
      directory: realpath.dirname.to_s,
      basename: realpath.basename.to_s,
    }
  end

  def filename
    File.join(directory, basename)
  end

  def deleted?
    Files.deleted?(directory)
  end

  def date_string
    self.taken_time&.split&.first
  end

  def identical
    Photo.where(sha1: self.sha1).exclude(:id => self.id)
  end

  def add_tag(tag)
    if tag.is_a?(String)
      add_tag(Tag.ensure(tag))
    else
      if !self.tags.include?(tag)
        super(tag)
        true
      end
    end
  end

  def remove_tag(tag)
    if tag.is_a?(String)
      tag = self.tags.detect{|t| t.tag == tag}
      if tag
        remove_tag(tag)
        true
      end
    else
      super(tag)
    end
  end

  def set_rating(rating)
    self.rating = rating
    self.save
  end

  def locked?
    self.protected != 0
  end

  def lock(protected = true)
    self.protected = protected ? 1 : 0
    self.save
  end

  def unlock
    lock(false)
  end

  class ExifData
    def initialize(filename)
      @filename = filename
    end

    def get_string(name)
      with_exif_data do |exif_data|
        exif_data[name]
      end
    end

    def with_exif_data(&block)
      if !@exif_data
        @exif_data =
          begin
            exiv2 = Exiv2::ImageFactory.open(@filename)
            exiv2.read_metadata
            exiv2.exif_data.to_h
          rescue
            :failed
          end
      end
      if @exif_data != :failed
        block.call(@exif_data)
      end
    end

    def get_real(name)
      string = get_string(name)
      if string
        n = string.split("/")
        r =
          case n.size
          when 1
            n[0].to_f
          when 2
            n[0].to_f / n[1].to_f
          else
            raise "Bad real: #{string}"
          end
        r != 0 ? r : nil
      end
    end

    def get_taken_time
      # exiftool goes to great lengths to deal with non-conforming
      # dates.  No idea what exiv2 does if anything, other than writing
      # lots of warnings to stderr.
      date = get_string("Exif.Photo.DateTimeOriginal")
      date = date.first if Array === date
      if date && date != "" && date !~ /^0/
        date, time = date.split(" ")
        date.gsub!(/:/, "-")
        "#{date} #{time}"
      end
    end
  end
end

class Tag < Sequel::Model
  many_to_many :photos
  one_to_many :phototags
  # Don't need this with on_delete cascade.
  plugin :association_dependencies, photos: :nullify

  def self.ensure(tag)
    Tag.find_or_create(tag: tag) do |t|
      t.created_at = Time.now
    end
  end
end

# Need to define PhotoTag so we can roll our own query in
# Tagger#load_directory_tags because dataset_associations has
# problems.
#
class Phototag < Sequel::Model(:photos_tags)
  many_to_one :tag
  many_to_one :photo
end

class Last < Sequel::Model
  # Need this to allow first_or_create to set the directory column.
  unrestrict_primary_key
end
