require_relative "../files"

def process_args(args, recurse, &block)
  args.each do |filename|
    Files.image_files(filename, recurse).each(&block)
  end
end
