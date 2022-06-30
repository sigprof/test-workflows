{pkgs ? import <nixpkgs> {}}: let
  inherit (pkgs) system;

  # Load this flake using `edolstra/flake-compat`.  Note that the resulting
  # flake refers to the locked `nixpkgs` revision, and therefore is not
  # suitable for the NUR use case, but some parts from that flake can still be
  # used without causing a download of that `nixpkgs` revision.
  selfFlakeCompat =
    (import (let
      lock = builtins.fromJSON (builtins.readFile ./flake.lock);
      inherit (lock.nodes.flake-compat.locked) owner repo rev narHash;
    in
      fetchTarball {
        url = "https://github.com/${owner}/${repo}/archive/${rev}.tar.gz";
        sha256 = narHash;
      }) {src = ./.;})
    .defaultNix;

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
      inherit (selfFlakeCompat.inputs.flake-utils.lib) filterPackages flattenTree;
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
