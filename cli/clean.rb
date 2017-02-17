#!/usr/bin/env ruby

require "bundler/setup"
require "trollop"
require "fileutils"
require "byebug"

# clean directory ...
# For each argument:
#   Remove .deleted directories
#   Remove empty directories
#   Remove .bak files
#   tag purge -r <directory>

options = Trollop::options do
  banner <<EOS
Usage: #{$0} directory...
Get rid of cruft in directories and database:
- remove .deleted directories
- remove empty directories
- remove .bak files
- tag purge -r <directory> to remove database entries
  without a corresponding file
EOS
end

def clean(directory)
  Dir.glob(File.join(directory, "**", ".deleted")) do |deleted|
    FileUtils.remove_dir(deleted)
  end
  %x{tag purge -r #{directory}}
  %x{find "#{directory}" "(" -type d -empty -o -name "*.bak" ")" -delete}
end

ARGV.each do |directory|
  clean(directory)
end

