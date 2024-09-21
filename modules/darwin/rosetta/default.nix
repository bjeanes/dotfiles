{ system, lib, ... }: {
  config = {
    nix = lib.optionalAttrs (system == "aarch64-darwin") {
      extraOptions = ''
        extra-platforms = aarch64-darwin x86_64-darwin;
      '';
    };
  };
}
