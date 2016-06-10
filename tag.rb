#!/usr/bin/env ruby

require "pathname"

cmd = ARGV.shift
cli = File.join(File.dirname(Pathname.new(__FILE__).realpath), "cli")
cmd_file = File.join(cli, "#{cmd}.rb")
if File.exist?(cmd_file)
  load cmd_file
else
  puts "#{$0} commands:"
  cmds = Dir[File.join(cli, "*.rb")].map do |cmd|
    File.basename(cmd).sub(/\.rb$/, "")
  end.sort.join(" ")
  puts "  #{cmds}"
  exit 1
end
