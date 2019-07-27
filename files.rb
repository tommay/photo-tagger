require "strscan"

module Files
  SUFFIXES = ["jpg", "png", "tif", "tiff"].map do |suffix|
    %r{\.#{suffix}$}i
  end

  def self.image_file?(filename)
    SUFFIXES.any? do |suffix|
      filename =~ suffix
    end
  end

  def self.deleted?(dirname)
    File.basename(dirname) == ".deleted"
  end

  def self.for_directory(dirname)
    Dir[dirname ? File.join(dirname, "*") : "*"].select do |filename|
      image_file?(filename)
    end.sort_by{|name| split_name(name)}
  end

  def self.image_files(filename, recurse=false)
    Enumerator.new do |yielder|
      enumerate_image_files(filename, recurse, true, yielder)
    end
  end

  # XXX private
  def self.enumerate_image_files(filename, recurse, top, yielder)
    case
    when (top || recurse) && File.directory?(filename) &&
         !Files.deleted?(filename)
      (Dir[File.join(filename, "*")] rescue []).each do |f|
        enumerate_image_files(f, recurse, false, yielder)
      end
    when image_file?(filename)
      yielder << filename
    end
  end

  # Split a string into an Array of alternating non-numerics and
  # numerics.  The arrays can then be compared, and numbers will sort
  # in numeric order instead of alphabetic, e.g., "spud_9" sorts
  # before "spud_10".  "spud_1" compares equal to "spud_01" but that
  # shouldn't be a problem.  But to be sure, equal numbers are orders
  # by the length of their string, e.g., "1", "01", "001".  Not ideal
  # but it shouldn't be a problem.
  #
  def self.split_name(string)
    string.split(/([0-9]+)/).map do |s|
      if s =~ /[0-9]/
        [s.to_i, s.size]
      else
        s
      end
    end
  end
end
