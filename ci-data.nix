{pkgs ? import <nixpkgs> {}}: let
  self = import ./nur.nix {inherit pkgs;};
in {
  inherit (self.lib) ciData;
}
