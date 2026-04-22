{
  config,
  lib,
  myLib,
  pkgs,
  namespace,
  ...
}:
let
  svc = "llama";
  myLib = lib.${namespace};
in
{
  options.homelab.services.${svc} = {
    enable = lib.mkOption {
      default = false;
      type = lib.types.bool;
      description = "Enable ${svc}";
    };
  };

  config =
    let
      cfg = config.homelab.services.${svc};
    in
    (lib.mkIf cfg.enable (
      lib.mkMerge [
        {
          virtualisation.oci-containers.containers = {
            ${svc} =
              let
                version = "prism-b8846-d104cf1";
                image = "localhost/llama-cpp";
              in
              {
                image = "${image}:${version}";
                extraOptions = [ "--dns=1.1.1.1" ];
                imageFile =
                  let
                    binaries = pkgs.fetchzip {
                      url = "https://github.com/PrismML-Eng/llama.cpp/releases/download/${version}/llama-${version}-bin-ubuntu-x64.tar.gz";
                      hash = "sha256-cT2lKgvRGRGpRrNEUtupCIMHh7mCpNqjv5NnS9CxCBc=";
                      stripRoot = true;
                    };

                    llamaBinaries = pkgs.runCommand "llama-bins" { } ''
                      mkdir -p $out/app
                      cp -r ${binaries}/llama-${version}/* $out/app/
                      chmod -R +x $out/app/
                    '';

                    runtimePath = lib.makeBinPath (
                      with pkgs;
                      [
                        bash
                        coreutils
                      ]
                    );

                    libs = [
                      pkgs.glibc
                      pkgs.gcc.cc.lib
                      pkgs.openssl
                    ];
                  in
                  pkgs.dockerTools.buildLayeredImage {
                    name = image;
                    tag = version;

                    contents = libs ++ [
                      pkgs.bash
                      pkgs.coreutils
                      pkgs.cacert
                      llamaBinaries
                    ];

                    fakeRootCommands = /* bash */ ''
                      mkdir -p ./models
                    '';

                    config = {
                      Cmd = [
                        "/app/llama-server"
                        "--port"
                        "8080"
                        "--model-url"
                        "https://huggingface.co/prism-ml/Ternary-Bonsai-4B-gguf/resolve/main/Ternary-Bonsai-4B-Q2_0.gguf"
                        # "--hf-repo"
                        # "prism-ml/Ternary-Bonsai-8B-gguf"
                        # "--hf-file"
                        # "Ternary-Bonsai-8B-Q2_0.gguf"
                      ];
                      Volumes."/models" = { };
                      Env = [
                        "PATH=${runtimePath}"
                        "LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath libs}"
                        "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
                      ];
                      WorkingDir = "/models";
                    };
                  };

              };
          };
        }
        (myLib.mkTailscaleContainer pkgs config "${svc}-tailscale" {
          hostname = svc;
          serve = {
            TCP."443".HTTPS = true;
            Web."\${TS_CERT_DOMAIN}:443".Handlers."/".Proxy = "http://localhost:8080";
          };
          container = {
            extraOptions = [ "--network=container:${svc}" ];
            dependsOn = [
              svc
            ];
          };
        })
      ]

    ));
}
