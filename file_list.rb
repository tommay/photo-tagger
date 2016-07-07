require_relative "restore"

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
    restore = Restore.new(@nfile, current) do |nfile, current|
      @filenames.insert(nfile, current)
      @nfile = nfile
    end

    @filenames.delete_at(@nfile)
    if @nfile >= @filenames.size
      @nfile -= 1
    end

    restore
  end

  def fake_delete_current
    Restore.new(@nfile) do |nfile|
      @nfile = nfile
    end
  end

  def next(delta = 1)
    if @filenames.size > 0
      @nfile = (@nfile + delta) % @filenames.size
    end
    @filenames[@nfile]
  end
end
