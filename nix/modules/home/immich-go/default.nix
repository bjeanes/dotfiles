{
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  hasSecret = name: (osConfig.age.secrets or { }) ? ${name};

  immichGo = pkgs.writeShellApplication {
    name = "immich-go";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      # In the environment because `ps` shows arguments to every user. If the
      # caller has already set either one, even to empty, theirs wins.
      if [[ ! -v IMMICH_GO_UPLOAD_API_KEY ]]; then
        IMMICH_GO_UPLOAD_API_KEY=$(tr -d '\r\n' <${osConfig.age.secrets.immich-go-api-key.path})
        export IMMICH_GO_UPLOAD_API_KEY
      fi
      export IMMICH_GO_UPLOAD_SERVER=''${IMMICH_GO_UPLOAD_SERVER-https://photos.griffin-climb.ts.net}

      exec ${lib.getExe pkgs.immich-go} "$@"
    '';
  };
in
{
  home.packages = lib.optional (hasSecret "immich-go-api-key") immichGo;
}
