# Only the Home Manager config, its inputs and flake.lock come from
# `sourceFlake`, which may be an older revision. Everything else comes from
# `flake`, the revision doing the rendering.
{
  pkgs,
  flake,
  sourceFlake ? flake,
  ...
}:
let
  inherit (pkgs) lib;
  inherit (sourceFlake) inputs;

  inherit (pkgs.stdenv.hostPlatform) system isDarwin;

  # Revisions from before the `home` host fall back to a real host's config.
  hm =
    sourceFlake.legacyPackages.${system}.homeConfigurations."bjeanes@home".config or (
      if isDarwin then
        sourceFlake.darwinConfigurations.Jabberwocky
      else
        sourceFlake.nixosConfigurations.Borogrove
    ).config.home-manager.users.bjeanes;

  lock = lib.importJSON "${sourceFlake}/flake.lock";
  upstreamUrl =
    locked:
    if locked.type == "github" then
      "https://github.com/${locked.owner}/${locked.repo}/tree/${locked.rev}"
    else
      locked.url or locked.type;

  # Store path => the input's name and where it was fetched from, for inputs the
  # config refers to directly (e.g. zsh plugins), which are otherwise all just
  # named "source".
  flakeInputs = lib.mapAttrs' (
    name: input:
    lib.nameValuePair (builtins.unsafeDiscardStringContext input.outPath) {
      inherit name;
      url = upstreamUrl lock.nodes.${lock.nodes.root.inputs.${name}}.locked;
    }
  ) (lib.filterAttrs (name: _: lib.isString (lock.nodes.root.inputs.${name} or null)) inputs);

  nixvim = lib.findFirst (p: p ? config.build.initFile) null hm.home.packages;
  nvimConfig = nixvim.config.build;
  nvimPlugins = lib.optionals (nixvim != null) (
    lib.filter (p: p.plugin.outPath != nvimConfig.extraFiles.outPath) (
      # Older nixvim has no build.plugins, only the option it's normalised from.
      nvimConfig.plugins
        or (map (p: if p ? plugin then p else { plugin = p; }) nixvim.config.extraPlugins)
    )
  );

  # nixvim keeps Neovim's config inside its `nvim` wrapper, out of Home
  # Manager's files.
  homeFiles =
    if nixvim == null then
      hm.home-files
    else
      pkgs.runCommand "home-files-with-nvim" { } ''
        cp -a ${hm.home-files} $out
        chmod -R u+w $out
        mkdir -p $out/.config/nvim $out/.local/share/nvim/site/pack/dotfiles/{start,opt}
        ln -s ${nvimConfig.initFile} $out/.config/nvim/init.lua
        cp -rs ${nvimConfig.extraFiles}/. $out/.config/nvim/
        ${lib.concatMapStrings (p: ''
          ln -s ${p.plugin} $out/.local/share/nvim/site/pack/dotfiles/${
            if p.optional or false then "opt" else "start"
          }/${lib.getName p.plugin}
        '') nvimPlugins}
      '';

  pluginUrl =
    plugin:
    let
      src = plugin.src or { };
      # A flake's own plugin is usually built from a filtered copy of its source.
      srcPath = builtins.unsafeDiscardStringContext (toString (src.origSrc or src.outPath or ""));
      input = lib.findFirst (path: srcPath == path || lib.hasPrefix "${path}/" srcPath) null (
        builtins.attrNames flakeInputs
      );
      # fetchFromGitHub leaves `rev` null when given a `tag` instead.
      ref = if src.rev or null != null then lib.removePrefix "refs/tags/" src.rev else src.tag or null;
    in
    if input != null then
      flakeInputs.${input}.url
    else if lib.hasPrefix "https://github.com/" (src.gitRepoUrl or "") && ref != null then
      "https://github.com/${src.owner}/${src.repo}/tree/${ref}"
    else
      src.gitRepoUrl or src.url or null;

  # Store path => a name and where its code comes from, for flake inputs and
  # Neovim plugins.
  sources =
    flakeInputs
    // lib.listToAttrs (
      lib.filter (source: source.value.url != null) (
        map (
          p:
          lib.nameValuePair (builtins.unsafeDiscardStringContext p.plugin.outPath) {
            name = lib.getName p.plugin;
            url = pluginUrl p.plugin;
          }
        ) nvimPlugins
      )
    );

  # Store path => the home path it stands for.
  # Opened by the snacks dashboard's "Config" entry.
  nvimSource = lib.findFirst builtins.pathExists null [
    "${sourceFlake}/nix/packages/nvim"
    "${sourceFlake}/packages/nvim" # commits from before blueprint
  ];
  homeLinks = lib.optionalAttrs (nixvim != null && nvimSource != null) {
    ${builtins.unsafeDiscardStringContext "${builtins.path {
      path = nvimSource;
      name = "nvim";
    }}"} =
      ".config/nvim";
  };

  # Read from `sourceFlake`, the revision being rendered, instead of `flake`.
  # Older revisions have no README, so their renders don't either.
  readme = "${sourceFlake}/nix/packages/dotfiles/README.md";
in
pkgs.runCommand "dotfiles"
  {
    nativeBuildInputs = [
      pkgs.luajit
      pkgs.ruby
      pkgs.zsh
    ];
    allowedReferences = [ ];
    passthru.render = sourceFlake: import ./. { inherit pkgs flake sourceFlake; };
  }
  ''
    cp -RL ${homeFiles} $out
    chmod -R u+w $out
    ruby ${./render.rb} \
      ${homeFiles} \
      ${hm.home.homeDirectory} \
      ${pkgs.writeText "sources.json" (builtins.toJSON sources)} \
      ${pkgs.writeText "home-links.json" (builtins.toJSON homeLinks)} \
      $out
    ${lib.optionalString (builtins.pathExists readme) "cp ${readme} $out/README.md"}

    # Dropping Nix-only lines can leave a block empty, which breaks the file.
    for f in .bashrc .bash_profile .profile; do
      [ ! -e "$out/$f" ] || bash -n "$out/$f"
    done
    for f in .zshrc .zshenv .zprofile; do
      [ ! -e "$out/$f" ] || zsh -n "$out/$f"
    done
    for f in $(find $out -name '*.lua'); do
      luajit -bl "$f" >/dev/null
    done
  ''
