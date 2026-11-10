# Rewrites a copy of Home Manager's `home-files` into a plain home directory
# with no /nix/store references, for sharing with people who don't use Nix.
#
# Usage: project.rb HOME_FILES HOME_DIRECTORY FLAKE_INPUTS_JSON OUT

require "fileutils"
require "json"
require "pathname"
require "set"

STORE_REF = %r{/nix/store/[0-9a-z]{32}-[A-Za-z0-9+\-._?=]+(?:/[A-Za-z0-9+\-._?=@%]+)*}
STORE_SHEBANG = %r{\A#!/nix/store/[^/]+/bin/}

SINGLE_QUOTED = /'([^'"$`\\]+)'/  # with no ", $, ` or \ inside, which double quotes treat specially
LUA_STRING = /"([^"\s]+)"/

EXCLUDED = [
  ".cache/nix-index",                                         # nix-index's database
  ".config/systemd/user/agenix.service",                      # decrypts Nix-managed secrets
  ".config/systemd/user/default.target.wants/agenix.service",
  ".config/fontconfig",                                       # only points into home-manager-path
  ".config/direnv/lib/hm-nix-direnv.sh"                       # nix-direnv's hook
].freeze

DROPPED_BLOCKS = [
  # Sources Nix's bash-completion, which is most of the projection's size.
  # Distros and Homebrew load their own, which is what the guard checks for.
  /^if \[\[ ! -v BASH_COMPLETION_VERSINFO \]\]; then\n.*\n^fi\n\n?/
].freeze

DROPPED_LINES = [
  %r{nix-index.*/command-not-found},  # needs nix-index's database
  %r{^\s*HELPDIR=.*/nix/store/},      # zsh's own help files
  %r{^\s*(export\s+)?LOCALE_ARCHIVE}, # only Nix's glibc reads it
  %r{PATH=.*/nix/store/[^/]+/bin:}    # packages are assumed to be on $PATH
].freeze

SHELL_NAMES = %w[.bashrc .bash_profile .profile .zshrc .zshenv .zprofile].freeze
SHELL_EXTS = %w[.sh .bash .zsh].freeze

VENDOR_DIR = ".local/share/dotfiles"
BIN_DIR = ".local/bin"
UPSTREAM_README = "#{VENDOR_DIR}/README.md"

VERSION_SUFFIX = /-(?:\d|unstable-).*\z/

BINARY_SNIFF_BYTES = 8000

Command = Data.define(:name)   # on $PATH, written bare
HomePath = Data.define(:path)  # relative to $HOME

HomeLink = Data.define(:rel, :object, :root)

class Projection
  def initialize(home_files, home_directory, flake_inputs, out)
    @home_files = home_files
    @home_dir_ref = /#{Regexp.escape(home_directory)}(?![\w.-])/  # not /home/bjeanes2
    @flake_inputs = JSON.parse(File.read(flake_inputs))
    @out = Pathname(out)
    @home_links = store_objects_linked_into_home
    @linked_objects = @home_links.select(&:root).to_h { |link| [link.object, link.root] }
    @upstream = {}  # home path => where its code comes from
    @labels = {}
    @vendored = Set.new
    @queue = []
  end

  def run
    EXCLUDED.each { |path| FileUtils.rm_rf(@out / path) }
    @home_links.select { upstream?(_1.object) }.each do |link|
      FileUtils.rm_rf(@out / link.rel)
      @upstream[link.rel] = describe(link.object)
    end
    each_file(@out) { |file| queue_text_or_drop_binary(file) }
    # Since vendoring a store file queues it too, its own references get rewritten as well.
    rewrite(@queue.shift) until @queue.empty?
    write_upstream_readme
    system("find", @out.to_s, "-mindepth", "1", "-type", "d", "-empty", "-delete", exception: true)
    assert_no_store_references
  end

  # Home Manager links store objects into home, whole or file-by-file. So
  #   .claude/skills/foo/SKILL.md -> /nix/store/abc-foo/SKILL.md
  # gives a link whose root is ".claude/skills/foo". References to that object
  # can then point at the copy already in the projection.
  private def store_objects_linked_into_home
    Dir.glob("**/*", File::FNM_DOTMATCH, base: @home_files).filter_map do |rel|
      path = File.join(@home_files, rel)
      next if excluded?(rel) || !File.symlink?(path)

      object, subpath = split_store_path(File.readlink(path))
      HomeLink[rel, object, (rel.delete_suffix(subpath) if rel.end_with?(subpath))] if object
    end
  end

  private def rewrite(file)
    text = file.binread
    return unless text.include?("/nix/store/") || text.match?(@home_dir_ref)

    dialect = dialect_for(file, text)
    text = rewrite_shebang(text)
    text = drop_nix_only_code(text)
    text = localise_quoted_paths(text, dialect)
    text = localise(text, home: dialect == :shell ? "$HOME" : "~")
    file.binwrite(text)
  end

  private def rewrite_shebang(text)
    text.sub(STORE_SHEBANG, "#!/usr/bin/env ")
  end

  private def drop_nix_only_code(text)
    text = DROPPED_BLOCKS.reduce(text) { |remaining, block| remaining.gsub(block, "") }
    text.lines.reject { |line| DROPPED_LINES.any? { _1.match?(line) } }.join
  end

  # An absolute path that was fine in single quotes becomes $HOME-relative here,
  # which shell only expands inside double quotes.
  #
  # Since Lua has no shorthand for $HOME, this splices in os.getenv("HOME")
  # with `..`.
  private def localise_quoted_paths(text, dialect)
    case dialect
    when :shell
      text.gsub(SINGLE_QUOTED) do
        path = localise($1, home: "$HOME")
        path.include?("$HOME") ? %("#{path}") : "'#{path}'"
      end
    when :lua
      text.gsub(LUA_STRING) do
        localise($1, home: "$HOME")
          .split("$HOME", -1)
          .map { %("#{_1}") }
          .join(%( .. os.getenv("HOME") .. ))
          .delete_prefix(%("" .. ))
          .delete_suffix(%( .. ""))
      end
    else
      text
    end
  end

  private def localise(text, home:)
    text
      .gsub(STORE_REF) do |ref|
        case resolve(ref)
        in Command[name] then name
        in HomePath[path] then "#{home}/#{path}"
        end
      end
      .gsub(@home_dir_ref, home)
  end

  private def resolve(ref)
    object, subpath = split_store_path(ref)

    # A package's bin directory, such as /nix/store/…-claude/bin. It only
    # appears where something adds it to PATH. DROPPED_LINES should have
    # removed that line. If one gets through, the pattern there needs widening.
    raise "can't localise #{ref}" if subpath == "/bin"

    # A program, the most common case. For example, git config's
    # `external = /nix/store/…-difftastic-0.71.0/bin/difft` becomes `difft`.
    command = subpath[%r{\A/bin/([^/]+)\z}, 1]
    return Command[command] if command

    # A store object Home Manager also links into home. For example, a skill's
    # SKILL.md naming its own scripts at /nix/store/…-skill-foo/scripts/x.sh
    # can name the linked copy under ~/.claude/skills/foo instead.
    return HomePath[@linked_objects[object] + subpath] if @linked_objects.key?(object)

    # Code from elsewhere, usually a plugin or theme that gets sourced. For
    # example, .zshrc sourcing
    # /nix/store/…-zsh-autosuggestions-0.7.1/share/zsh-autosuggestions/zsh-autosuggestions.zsh.
    # The path stays as it is. UPSTREAM_README says what belongs there.
    label = label_for(object)
    if upstream?(object)
      @upstream["#{VENDOR_DIR}/#{label}"] ||= describe(object)
      return HomePath["#{VENDOR_DIR}/#{label}#{subpath}"]
    end

    # A script that is a store object of its own, as writeShellScript makes.
    # For example, /nix/store/…-git-push-notes. Since it's usually glue this
    # config wrote, which no package manager would provide, it ships in
    # BIN_DIR.
    path = Pathname(ref)
    if subpath.empty? && path.file? && path.executable?
      vendor(path, "#{BIN_DIR}/#{label}")
      return Command[label]
    end

    # Anything else this config generated, such as .zprofile sourcing
    # /nix/store/…-hm-session-vars.sh/etc/profile.d/hm-session-vars.sh. Copy
    # the whole directory around a file, so that anything sourced from beside
    # it comes too. A path that doesn't exist stays a path to nothing.
    if path.exist?
      source = path.file? && !subpath.empty? ? path.dirname : path
      vendor(source, "#{VENDOR_DIR}/#{label}/#{source.relative_path_from(object)}")
    end
    HomePath["#{VENDOR_DIR}/#{label}#{subpath}"]
  end

  # The store name minus its version, so that a version bump changes the
  # vendored files rather than their paths.
  private def label_for(object)
    @labels[object] ||= unique_label(@flake_inputs.dig(object, "name") || name_without_version(object))
  end

  private def name_without_version(object)
    store_name(object).sub(VERSION_SUFFIX, "")
  end

  private def store_name(object)
    object.sub(%r{\A/nix/store/[^-]+-}, "")
  end

  # Assumes nothing this config generates has a version suffix or is named
  # "source". If UPSTREAM_README lists something it shouldn't, look here.
  private def upstream?(object)
    @flake_inputs.key?(object) || store_name(object) == "source" || store_name(object).match?(VERSION_SUFFIX)
  end

  #   flake input         => "https://github.com/owner/repo/tree/<rev>"
  #   zsh-vi-mode-0.12.0  => "zsh-vi-mode 0.12.0"
  private def describe(object)
    return @flake_inputs[object]["url"] if @flake_inputs.key?(object)

    name = name_without_version(object)
    "#{name} #{store_name(object).delete_prefix("#{name}-")}".strip
  end

  private def write_upstream_readme
    return if @upstream.empty?

    rows = @upstream.sort.map { |path, source| "| `~/#{path}` | #{source} |" }
    readme = @out / UPSTREAM_README
    readme.dirname.mkpath
    readme.write(<<~MARKDOWN)
      # Third-party code

      This configuration loads the files below from other projects, which aren't
      included here. To use one, please install it from its source at the path
      given.

      Where the source is only a name and version, it's a package from nixpkgs.
      Your package manager may have it under the same name.

      | Path | Source |
      | --- | --- |
      #{rows.join("\n")}
    MARKDOWN
  end

  private def unique_label(name)
    taken = @labels.values
    return name unless taken.include?(name)

    (2..).lazy.map { "#{name}-#{_1}" }.find { !taken.include?(_1) }
  end

  private def vendor(source, rel)
    dest = Pathname(File.expand_path(rel, @out))
    return if @vendored.include?(dest)

    @vendored << dest
    warn "vendoring #{source} as #{dest.relative_path_from(@out)}"
    dest.dirname.mkpath
    if source.directory?
      dest.mkpath
      system("cp", "-RL", "#{source}/.", dest.to_s, exception: true)
    else
      system("cp", "-L", source.to_s, dest.to_s, exception: true)
    end
    system("chmod", "-R", "u+w", dest.to_s, exception: true)
    each_file(dest) { |file| queue_text_or_drop_binary(file) }
  end

  private def queue_text_or_drop_binary(file)
    if binary?(file)
      warn "dropping binary #{file.relative_path_from(@out)}"
      file.delete
    else
      @queue << file
    end
  end

  private def dialect_for(file, text)
    case
    when file.extname == ".lua" then :lua
    when SHELL_NAMES.include?(file.basename.to_s) then :shell
    when SHELL_EXTS.include?(file.extname) then :shell
    when file.dirname.basename.to_s == "environment.d" then :shell  # systemd expands $HOME, not ~
    when text.start_with?("#!") && text.lines.first.match?(/sh\b/) then :shell
    else :other
    end
  end

  private def excluded?(rel)
    EXCLUDED.any? { |path| rel == path || rel.start_with?("#{path}/") }
  end

  #   "/nix/store/abc-foo/share/x.zsh" => ["/nix/store/abc-foo", "/share/x.zsh"]
  #   "/nix/store/abc-foo"             => ["/nix/store/abc-foo", ""]
  #   "/etc/zshrc"                     => nil
  private def split_store_path(path)
    path.match(%r{\A(/nix/store/[^/]+)(.*)\z})&.captures
  end

  private def assert_no_store_references
    dirty = []
    each_file(@out) { |file| dirty << file.relative_path_from(@out) if file.binread.include?("/nix/store/") }
    abort "store references remain in:\n  #{dirty.join("\n  ")}" unless dirty.empty?
  end

  private def each_file(root)
    return yield(root) if root.file?

    Dir.glob("**/*", File::FNM_DOTMATCH, base: root).sort.each do |rel|
      path = root / rel
      yield path if path.file?
    end
  end

  private def binary?(file)
    file.binread(BINARY_SNIFF_BYTES).to_s.include?("\0")  # binread gives nil for an empty file
  end
end

Projection.new(*ARGV).run
