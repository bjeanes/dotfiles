{
  lib,
  pkgs,
  ...
}:
let
  version = "1.6.0";
in
pkgs.stdenv.mkDerivation {
  pname = "touchkio";
  inherit version;

  src = pkgs.fetchurl {
    url = "https://github.com/leukipp/touchkio/releases/download/v${version}/touchkio-linux-x64-${version}.zip";
    hash = "sha256-j6WuEpG2HwOXOPWpVC8MqJeq9m0hH+EZ/5Z4siGw9IA=";
  };

  nativeBuildInputs = with pkgs; [
    unzip
    makeWrapper
  ];

  # Upstream matches only ALS name "als" (ours is "acpi-als"), demands
  # $DISPLAY on a Wayland session, has no way to suppress its own 40px title
  # bar outside debug mode (a tiled sway window reads as "Framed"), and takes
  # the MQTT password only via argv (world-readable) or a JSON file.
  postPatch = ''
    substituteInPlace resources/app/js/hardware.js \
      --replace-fail 'if (name === "als") {' \
                     'if (["als", "acpi-als"].includes(name)) {'

    substituteInPlace resources/app/js/webview.js \
      --replace-fail 'const height = force === "ON" ? 40 : force === "OFF" ? 0 : header.height > 0 ? 0 : 40;' \
                     'const height = 0;'

    substituteInPlace resources/app/js/integration.js \
      --replace-fail 'const password = ARGS.mqtt_password || null;' \
                     'const password = ARGS.mqtt_password_file ? require("fs").readFileSync(ARGS.mqtt_password_file, "utf8").replace(/\s+$/, "") : ARGS.mqtt_password || null;'

    substituteInPlace resources/app/index.js \
      --replace-fail 'if (!process.env.DISPLAY) {' \
                     'if (!process.env.DISPLAY && !process.env.WAYLAND_DISPLAY) {'
  '';

  # The release bundles its own Electron, but ships resources/app unpacked with
  # node_modules vendored, so run that under nixpkgs' electron instead of
  # autopatchelfing 300MB of Chromium. Upstream asks for electron 44; nixpkgs
  # has 43.
  installPhase = ''
    runHook preInstall

    app=resources/app
    test -f "$app/index.js"
    test -d "$app/node_modules"

    mkdir -p $out/share/touchkio
    cp -r "$app"/. $out/share/touchkio/

    makeWrapper ${lib.getExe pkgs.electron_43} $out/bin/touchkio \
      --add-flags $out/share/touchkio \
      --add-flags "--ozone-platform=wayland" \
      --add-flags "--enable-wayland-ime" \
      --add-flags "--wayland-text-input-version=3" \
      --prefix PATH : ${
        lib.makeBinPath (
          with pkgs;
          [
            wlopm
            pulseaudio
            coreutils
            systemd
          ]
        )
      }

    runHook postInstall
  '';

  meta = {
    description = "Home Assistant touch kiosk with MQTT integration";
    homepage = "https://github.com/leukipp/touchkio";
    license = lib.licenses.mit;
    mainProgram = "touchkio";
    platforms = [ "x86_64-linux" ];
  };
}
