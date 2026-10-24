{
  lib,
  fetchFromGitHub,
  rustPlatform,
  git,
  installAgentSkills,
  jujutsu,
  nix-update-script,
  writableTmpDirAsHomeHook,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "jj-hunk-tool";
  version = "0.1.0-unstable-2026-10-23";

  src = fetchFromGitHub {
    owner = "mvzink";
    repo = "jj-hunk-tool";
    rev = "97ebf97ba37fc8304c81bac1ba3272bdfe207d0f";
    hash = "sha256-MgJVU1jnfHagVD4gkFnAGf3oVUZyjgBhY60fteW+hAg=";
  };

  cargoHash = "sha256-rYur4UdaNcNepta03/98++IsqZb6Fo9F9w7YCByWiUU=";

  __structuredAttrs = true;

  # Installs upstream's skills/ into $out/share/skills/jj-hunk-tool.
  nativeBuildInputs = [ installAgentSkills ];

  # Integration tests drive a real jj repository.
  nativeCheckInputs = [
    git
    jujutsu
    writableTmpDirAsHomeHook
  ];

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--version=branch" ];
  };

  meta = {
    description = "Non-interactive hunk-level operations for Jujutsu (jj)";
    homepage = "https://github.com/mvzink/jj-hunk-tool";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ sei40kr ];
    mainProgram = "jj-hunk-tool";
  };
})
