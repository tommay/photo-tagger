require_relative "model"
require_relative "xmp"

module Exporter
  def self.export_to_sidecar(filename)
    # Find a database entry if we have one.  If we don't, there is
    # nothing to export.

    photo = Photo.find(filename)
    photo && export_photo_to_sidecar(photo)
  end

  def self.export_photo_to_sidecar(photo)
    # Load a sidecar file if one exists.  Otherwise, start with a
    # minimal document that sets up the proper elements and namespaces.

    xmp_filename = photo.filename + ".xmp"
    xmp =
      begin
        Xmp.new(File.read(xmp_filename))
      rescue Errno::ENOENT
        Xmp.new
      end

    # Set the sha1.

    xmp.set_sha1(photo.sha1)

    # Add the photo's tags.

    photo.tags.each do |tag|
      xmp.add_tag(tag.tag)
    end

    # Set the photo's rating if any.

    if photo.rating
      xmp.set_rating(photo.rating)
    end

    # Make a backup of the original xmp and save the new one.

    begin
      File.rename(xmp_filename, xmp_filename + ".0")
    rescue Errno::ENOENT
    end
    File.write(xmp_filename, xmp.to_s)
  end
end
