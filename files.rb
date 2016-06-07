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
end
