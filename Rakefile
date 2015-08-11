require 'yaml'

desc "install the dot files into user's home directory"
task :install do
  dot_files = File.dirname(__FILE__)
  install   = proc do |files, cmd|
    files.each do |source, destination|
      source      = File.expand_path(source, dot_files)
      destination = File.expand_path(destination, ENV['HOME'])
      system 'mkdir', '-p', File.dirname(destination)
      # puts [*cmd, source, destination].join(" ")
      system *cmd, source, destination
    end
  end

  plan = YAML.load_file(File.expand_path("install.yml", dot_files))

  install.call plan[:link], %w[ln -sinF]
  install.call plan[:copy], %w[cp -i]
end
