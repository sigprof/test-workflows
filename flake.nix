{
  description = "Test flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = args @ {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      packages = flake-utils.lib.filterPackages system (flake-utils.lib.flattenTree {
        inherit (pkgs) hello firefox jq;
        default = pkgs.hello;
      });
      checks = self.lib.attrsets.removeNullsFromAttrs {
        default-package = self.packages.${system}.default or null;
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
      lib = import ./lib args;
    });
}
