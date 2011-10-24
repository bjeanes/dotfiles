require 'rake'

desc "install the dot files into user's home directory"
task :install do
  replace_all = false
  dot_files   = File.dirname(__FILE__)
  files       = %w(shells/zsh/zshrc
                   shells/zsh/zshenv
                   shells/bash/bashrc
                   shells/bash/bash_profile
                   misc/ackrc
                   misc/inputrc
                   misc/nanorc
                   misc/ctags
                   ruby/autotest/autotest
                   ruby/gemrc
                   ruby/irbrc
                   ruby/rdebugrc
                   git/gitk
                   git/gitconfig
                   git/gitignore
                   git/gitattributes
                   hg/hgrc
                   vim
                   vim/gvimrc
                   vim/vimrc)

  files = Hash[files.zip(Array.new(files.size, "~/."))]
  files["ruby/global.gems"] = "~/.rvm/gemsets/"

  files.each do |file, destination|
    file_name        = file.split(/\//).last
    source_file      = File.join(dot_files, file)
    destination_file = File.expand_path("#{destination}#{file_name}")

    if File.exist?(destination_file) || File.symlink?(destination_file)
      if replace_all
        replace_file(destination_file, source_file)
      else
        print "overwrite #{destination_file}? [ynaq] "
        case $stdin.gets.chomp.downcase
        when 'a'
          replace_all = true
          replace_file(destination_file, source_file)
        when 'y'
          replace_file(destination_file, source_file)
        when 'q'
          exit
        else
          puts "skipping #{destination_file}"
        end
      end
    else
      link_file(destination_file, source_file)
    end
  end

  File.open(File.expand_path("~/.dot-files"), 'w') do |f|
    f.print "export DOT_FILES=#{File.dirname(__FILE__).inspect}"
  end
end

def replace_file(old_file, new_file)
  system %Q{rm "#{old_file}"}
  link_file(old_file, new_file)
end

def link_file(old_file, new_file)
  puts "#{old_file} => #{new_file}"
  system %Q{ln -fs "#{new_file}" "#{old_file}"}
end
