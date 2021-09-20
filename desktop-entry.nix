{ pkgs, name, command, comment, destination }:

with pkgs;

writeTextFile {
  inherit name;
  inherit destination;
  text = ''
    [Desktop Entry]
    Type=Application
    Version=1.0
    Name=${name}
    Comment=${comment}
    Icon=xterm-color_48x48
    Exec=${command}
    Terminal=true
    Categories=System;Monitor;ConsoleOnly;
    Keywords=system;process;task
  '';
}
