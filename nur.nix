{pkgs ? import <nixpkgs> {}}: let
  inherit (pkgs) system;

  # Import the `flake-utils` flake manually (this code assumes that the
  # imported flake is hosted on GitHub, does not have any inputs and does not
  # need `sourceInfo`).
  flake-utils = let
    source = let
      lock = builtins.fromJSON (builtins.readFile ./flake.lock);
      inherit (lock.nodes.flake-utils.locked) owner repo rev narHash;
    in
      fetchTarball {
        url = "https://github.com/${owner}/${repo}/archive/${rev}.tar.gz";
        sha256 = narHash;
      };
    flake = import (source + "/flake.nix");
    outputs = flake.outputs {self = result;};
    result = outputs // {inherit outputs;};
  in
    result;

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

    nurPackages.${system} = let
      inherit (flake-utils.lib) filterPackages flattenTree;
    in
      filterPackages system (flattenTree (
        pkgs.callPackage ./pkgs {
          inherit (self) inputs;
          inherit pkgs;
        }
      ));
  };
in
  self
