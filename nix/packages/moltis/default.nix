{ pkgs, ... }:
let
  inherit (pkgs) lib;
  version = "20261023.01";
in
pkgs.stdenv.mkDerivation {
  pname = "moltis";
  inherit version;

  src = pkgs.fetchurl {
    url = "https://github.com/moltis-org/moltis/releases/download/${version}/moltis-${version}-x86_64-unknown-linux-gnu.tar.gz";
    hash = "sha256-kDjdhkbZ3bItq+U7nRsWQ5vT9MVNgXuKyuYwnJEQ3CQ=";
  };

  sourceRoot = ".";

  nativeBuildInputs = with pkgs; [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = with pkgs; [
    zlib
    stdenv.cc.cc.lib
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 moltis $out/libexec/moltis
    mkdir -p $out/share
    cp -r share/moltis $out/share/moltis

    makeWrapper $out/libexec/moltis $out/bin/moltis \
      --set MOLTIS_SHARE_DIR $out/share/moltis

    runHook postInstall
  '';

  meta = {
    description = "Persistent personal agent server";
    homepage = "https://github.com/moltis-org/moltis";
    license = lib.licenses.mit;
    mainProgram = "moltis";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
