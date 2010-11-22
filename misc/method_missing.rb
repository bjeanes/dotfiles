#!/usr/bin/env ruby

command = ARGV.shift

def run(cmd)
  puts "Running #{cmd.inspect} instead"
  exec(cmd)
end

case command
when /^git(@|:\/\/).*\.git$/
  run("git clone #{command.inspect}")
when /^(?:ftp|https?):\/\/.+\.t(?:ar\.)?gz$/
  run("curl #{command.inspect} | tar xzv")
when /^[a-z0-9_\-\/]+\.feature$/
  run("cucumber #{command}")
when /(.+)\.gem$/
  run("gem install #{$1}")
else
  $stderr.puts "No default action defined in #{__FILE__}"
  abort
end
