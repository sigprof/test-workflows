{
  description = "Test flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
    flake-utils.url = "github:numtide/flake-utils";

    flake-compat.url = "github:edolstra/flake-compat";
    flake-compat.flake = false;
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      packages = flake-utils.lib.filterPackages system (flake-utils.lib.flattenTree (
        let
          packages = pkgs.callPackage ./pkgs {inherit inputs;};
        in
          packages
          // {
            default = packages.hello;
          }
      ));
      checks = nixpkgs.lib.optionalAttrs (self?packages.${system}.default) {
        default-package = self.packages.${system}.default;
      };
    })
    // (let
      system = flake-utils.lib.system.x86_64-linux;
    in {
      nixosConfigurations = {
        "example/minimal" = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            {
              system.stateVersion = "22.05";
              networking.hostName = "minimal";
              fileSystems."/".device = "/dev/sda1";
              boot.loader.grub.device = "/dev/sda";
            }
          ];
        };
        "example/minimal2" = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            {
              system.stateVersion = "22.05";
              networking.hostName = "minimal2";
              fileSystems."/".device = "/dev/sda1";
              boot.loader.grub.device = "/dev/sda";
            }
          ];
        };
      };
      lib = import ./lib inputs;
    });
}
