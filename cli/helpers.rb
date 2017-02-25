require_relative "../files"

exit_on_epipe = lambda do |method|
  original_method = method(method)
  define_singleton_method(method) do |*args|
    begin
      original_method.call(*args)
    rescue Errno::EPIPE
      exit(1)
    end
  end
end

exit_on_epipe.call(:puts)
exit_on_epipe.call(:print)

def process_args(args, recurse, &block)
  args.each do |filename|
    Files.image_files(filename, recurse).each(&block)
  end
end
