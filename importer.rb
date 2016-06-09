require_relative "model"
require_relative "xmp"

module Importer
  def self.find_or_import_from_file(filename, copy_tags: false,
                                    purge_identical_images: false)
    # Fetch or create a database entry.

    photo = Photo.find_or_create(filename)

    # If requested, add tags from existing identical images.
    # XXX this should be the default.

    if copy_tags
      photo.identical.each do |identical|
        photo.tags += identical.tags
      end
    end

    # If there's an xmp sidecar file, read it and extract the tags.
    # XXX This appends tags without replacing the existing tags.

    xmp_filename = "#{filename}.xmp"
    if File.exist?(xmp_filename)
      xmp = Xmp.new(File.read(xmp_filename))
      xmp.get_tags.each do |tag|
        photo.add_tag(tag)
      end
    end

    photo.save

    # If requested, purge identical images that no longer exist.

    if purge_identical_images
      photo.identical.each do |identical|
        if !File.exist?(identical.filename)
          identical.destroy
        end
      end
    end

    photo
  end
end

