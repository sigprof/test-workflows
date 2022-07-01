{
  description = "Test flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      inherit (flake-utils.lib) filterPackages flattenTree;
      pkgs = nixpkgs.legacyPackages.${system};
      legacyPackages = pkgs.callPackage ./pkgs {inherit inputs;};
      packages = filterPackages system ((flattenTree legacyPackages)
        // {
          default = legacyPackages.hello;
        });
    in {
      inherit packages legacyPackages;
      checks = nixpkgs.lib.optionalAttrs (packages ? default) {
        default-package = packages.default;
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
