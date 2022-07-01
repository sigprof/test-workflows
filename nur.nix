{pkgs ? import <nixpkgs> {}}: let
  inherit (pkgs) system;

  # Make a flake-like structure for the current flake (only the parts that are
  # actually used by the code are filled in).
  self = {
    inputs = {
      inherit self;
      nixpkgs = {
        inherit (pkgs) lib;
        outPath = pkgs.path;
        legacyPackages.${system} = pkgs;
      };
    };
    lib = import ./lib self.inputs;

    # Use `nurPackages` instead of `packages`, so that the CI matrix generation
    # code creates the proper job names.
    nurPackages.${system} = let
      inherit (self.lib.packages) filterPackages flattenTree;
    in
      pkgs.callPackage ./pkgs {
        inherit (self) inputs;
        inherit pkgs;
      };
  };
in
  self
