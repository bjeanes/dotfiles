{
  pkgs,
  flake,
  inputs,
  ...
}:
let
  inherit (pkgs) lib;

  hm = flake.nixosConfigurations.Borogrove.config.home-manager.users.bjeanes;

  lock = lib.importJSON "${flake}/flake.lock";
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
in
pkgs.runCommand "dotfiles"
  {
    nativeBuildInputs = [
      pkgs.ruby
      pkgs.zsh
    ];
    allowedReferences = [ ];
  }
  ''
    cp -RL ${hm.home-files} $out
    chmod -R u+w $out
    ruby ${./render.rb} \
      ${hm.home-files} \
      ${hm.home.homeDirectory} \
      ${pkgs.writeText "flake-inputs.json" (builtins.toJSON flakeInputs)} \
      $out

    # Dropping Nix-only lines can leave a block empty, which breaks the file.
    for f in .bashrc .bash_profile .profile; do
      [ ! -e "$out/$f" ] || bash -n "$out/$f"
    done
    for f in .zshrc .zshenv .zprofile; do
      [ ! -e "$out/$f" ] || zsh -n "$out/$f"
    done
  ''
