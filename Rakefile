require 'rake'

desc "install the dot files into user's home directory"
task :install do
  replace_all = false
  dot_files   = File.dirname(__FILE__)
  files       = %w(
                   editors/vim
                   editors/vim/gvimrc
                   editors/vim/vimrc
                   languages/ruby/autotest/autotest
                   languages/ruby/gemrc
                   languages/ruby/irbrc
                   languages/ruby/rdebugrc
                   misc/ackrc
                   misc/ctags
                   misc/inputrc
                   misc/nanorc
                   misc/tmux.conf
                   shells/bash/bash_profile
                   shells/bash/bashrc
                   shells/zsh/zshenv
                   shells/zsh/zshrc
                   vcs/git/gitattributes
                   vcs/git/gitconfig
                   vcs/git/gitignore
                   vcs/git/gitk
                   vcs/git/git_template
                   vcs/hg/hgrc
                  )

  files = Hash[files.zip(Array.new(files.size, "~/."))]
  # files["ruby/global.gems"] = "~/.rvm/gemsets/"

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
end

def replace_file(old_file, new_file)
  system %Q{rm "#{old_file}"}
  link_file(old_file, new_file)
end

def link_file(old_file, new_file)
  puts "#{old_file} => #{new_file}"
  system %Q{ln -fs "#{new_file}" "#{old_file}"}
end
