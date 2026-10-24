# Claude Code's global rules, and nothing else of its setup: no package,
# settings or CLAUDE.md, which stay as they are on each machine.
{
  programs.claude-code = {
    enable = true;
    package = null;
    rulesDir = ./rules;
  };
}
