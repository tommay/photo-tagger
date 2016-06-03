module Files
  SUFFIXES = [%r{.jpg$}i, %r{.png$}i]

  def self.for_directory(dirname)
    filenames = Dir[dirname ? File.join(dirname, "*") : "*"]
    filenames.select do |filename|
      SUFFIXES.any? do |suffix|
        filename =~ suffix
      end
    end
  end
end
