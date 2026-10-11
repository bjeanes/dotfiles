{ lib, pkgs, ... }: {
  config = {
    nix = lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "aarch64-darwin") {
      extraOptions = ''
        extra-platforms = aarch64-darwin x86_64-darwin;
      '';
    };
  };
}
