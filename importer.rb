require_relative "model"
require_relative "xmp"

module Importer
  def self.find_or_import_from_file(
        filename, copy_tags_and_rating: false,
        purge_identical_images: false,
        force_purge: false)
    # Fetch or create a database entry.

    photo = Photo.find_or_create(filename) do |photo|
      # This is a new photo.

      # Existing photos don't use the xmp file because of an issue
      # where deleted tags would be re-added from the xmp file the
      # next time the photo was loaded.

      # Load an .xmp sidecar file is there is one.

      xmp_filename = "#{filename}.xmp"
      xmp = File.exist?(xmp_filename) && Xmp.new(File.read(xmp_filename))

      # Fill in the sha1 from xmp if we have it.  This saves saves
      # some (a lot of) time.

      if xmp
        photo.sha1 = xmp.get_sha1
      end

      # Copy tags and rating from an existing xmp sidecar file.

      if xmp
        xmp.get_tags.each do |tag|
          photo.add_tag(tag)
        end

        rating = xmp.get_rating
        if rating
          photo.set_rating(rating)
        end
      end
    end

    # Cache identical photos so we load it at most once.

    identical_photos = nil

    # If requested, add tags and rating from existing identical images.
    # XXX this should be the default.

    if copy_tags_and_rating
      identical_photos ||= photo.identical
      identical_photos.each do |identical|
        identical.tags.each do |tag|
          photo.add_tag(tag)
        end
        if !photo.rating
          photo.rating = identical.rating
        end
      end
      photo.modified? && photo.save
    end

    # If requested, purge identical images that no longer exist.  If
    # force_purge ten piurge them even if they do exist.

    if purge_identical_images
      identical_photos ||= photo.identical
      identical_photos.each do |identical|
        if force_purge || !File.exist?(identical.filename)
          identical.destroy
        end
      end
    end

    photo
  end
end

