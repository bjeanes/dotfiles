{
  autoCmd = [
    {
      # `agenix -e` edits the decrypted secret under its `.age` name, and the
      # newline vim would add ends up in the secret
      event = [
        "BufNewFile"
        "BufRead"
      ];
      pattern = "*.age";
      command = "setlocal nofixendofline noendofline";
    }
  ];
}
