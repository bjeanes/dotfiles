{
  plugins.mini = {
    modules = {
      hipatterns = {
        # Highlight standalone 'FIXME', 'HACK', 'TODO', 'NOTE'
        fixme = {
          pattern = "%f[%w]()FIXME()%f[%W]";
          group = "MiniHipatternsFixme";
        };
        hack = {
          pattern = "%f[%w]()HACK()%f[%W]";
          group = "MiniHipatternsHack";
        };
        todo = {
          pattern = "%f[%w]()TODO()%f[%W]";
          group = "MiniHipatternsTodo";
        };
        note = {
          pattern = "%f[%w]()NOTE()%f[%W]";
          group = "MiniHipatternsNote";
        };

        hex_color.__raw = # lua
          ''
            -- Highlight hex color strings (`#rrggbb`) using that color
            require('mini.hipatterns').gen_highlighter.hex_color()
          '';
      };
    };
  };
}
