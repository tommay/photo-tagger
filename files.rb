module Files
  SUFFIXES = ["jpg", "png"].map do |suffix|
    %r{\.#{suffix}$}i
  end

  def self.image_file?(filename)
    SUFFIXES.any? do |suffix|
      filename =~ suffix
    end
  end

  def self.for_directory(dirname)
    Dir[dirname ? File.join(dirname, "*") : "*"].select do |filename|
      image_file?(filename)
    end
  end

  def self.image_files(filename, recurse)
    Enumerator.new do |yielder|
      enumerate_image_files(filename, recurse, true, yielder)
    end
  end

  def self.enumerate_image_files(filename, recurse, top, yielder)
    case
    when (top || recurse) && File.directory?(filename)
      Dir[File.join(filename, "*")].each do |f|
        enumerate_image_files(f, recurse, false, yielder)
      end
    when image_file?(filename)
      yielder << filename
    end
  end
end
