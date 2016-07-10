require_relative "model"
require_relative "xmp"

module Importer
  def self.find_or_import_from_file(filename, copy_tags: false,
                                    purge_identical_images: false,
                                    force_purge: false)
    # Load an .xmp sidecar file is there is one.

    xmp_filename = "#{filename}.xmp"
    xmp = File.exist?(xmp_filename) && Xmp.new(File.read(xmp_filename))

    # Fetch or create a database entry.  Re-use an existing sha1 from
    # the xmp file to save time.

    photo = Photo.find_or_create(filename, sha1: xmp && xmp.get_sha1)

    # If requested, add tags from existing identical images.
    # XXX this should be the default.

    if copy_tags
      photo.identical.each do |identical|
        photo.tags += identical.tags
        if !photo.rating
          photo.rating = identical.rating
        end
      end
    end

    # If there's an xmp sidecar file, read it and extract the tags and the
    # rating.
    # XXX This appends tags without replacing the existing tags.

    xmp_filename = "#{filename}.xmp"
    if File.exist?(xmp_filename)
      xmp = Xmp.new(File.read(xmp_filename))
      xmp.get_tags.each do |tag|
        photo.add_tag(tag)
      end
      if !photo.rating
        rating = xmp.get_rating
        if rating
          photo.set_rating(rating)
        end
      end
    end

    photo.save

    # If requested, purge identical images that no longer exist.  If
    # force_purge ten piurge them even if they do exist.

    if purge_identical_images
      photo.identical.each do |identical|
        if force_purge || !File.exist?(identical.filename)
          identical.destroy
        end
      end
    end

    photo
  end
end

