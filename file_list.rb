class FileList
  def initialize(filename)
    if filename.is_a?(Array) && filename.size == 1
      filename = filename[0]
    end

    if filename.is_a?(Array)
      @filenames = filename.select do |f|
        Files.image_file?(f) && File.exist?(f)
      end.map{|f| Pathname.new(f).realpath.to_s}
      @nfile = 0
    else
      realpath = Pathname.new(filename).realpath.to_s
      case
      when File.directory?(realpath)
        @directory = realpath
        @filenames = Files.for_directory(@directory)
        @nfile = 0
      when File.exist?(realpath) && Files.image_file?(realpath)
        @directory = File.dirname(realpath)
        @filenames = Files.for_directory(@directory)
        @nfile = @filenames.find_index(realpath)
      else
        # XXX
        raise "Ugh."
        @filenames = []
        @nfile = 0
      end
    end
  end

  def current
    @filenames[@nfile]
  end

  def directory
    @directory || File.dirname(current)
  end

  def delete_current
    result = [@nfile, current]
    @filenames.delete_at(@nfile)
    if @nfile >= @filenames.size
      @nfile -= 1
    end
    result
  end

  def fake_delete_current
    [@nfile, current]
  end

  def undelete(deleted)
    @nfile = deleted[0]

    # Insert deleted[1] into @filenames unless it's already there,
    # e.g., we rotated the file and are restoring it.

    if @filenames[@nfile] != deleted[1]
      @filenames.insert(@nfile, deleted[1])
    end
  end

  def next(delta = 1)
    if @filenames.size > 0
      @nfile = (@nfile + delta) % @filenames.size
    end
    @filenames[@nfile]
  end
end