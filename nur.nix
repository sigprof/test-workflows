{pkgs ? import <nixpkgs> {}}: let
  inherit (pkgs) system;
  self = {
    NUR = true;
    inputs = {
      inherit self;
      nixpkgs = {
        inherit (pkgs) lib;
        outPath = pkgs.path;
        legacyPackages.${system} = pkgs;
      };
    };
    lib = import ./lib self.inputs;

    # FIXME: use `pkgs.callPackage`, then filter to usable packages only
    nurPackages.${system} = import ./pkgs {
      inherit (self) inputs;
      inherit pkgs;
    };
  };
in
  self
