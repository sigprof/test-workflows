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
      #checks = self.lib.removeNullValues {
      #  default-package = self.packages.${system}.default or null;
      #};
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
      };
      lib = import ./lib args;
      #lib = let
      #  inherit (nixpkgs.lib) isAttrs genAttrs attrNames filterAttrs;
      #  inherit (flake-utils.lib) defaultSystems;
      #  ciMatrix = name: attrs:
      #    if (!isAttrs attrs) || (attrs == {})
      #    then null
      #    else {
      #      ${name} = attrNames attrs;
      #    };
      #  ciPackagesFor = system: removeAttrs (self.packages.${system} or {}) ["default"];
      #  ciHostsFor = system:
      #    filterAttrs (n: v: v.config.nixpkgs.system == system) (self.nixosConfigurations or {});
      #in {
      #  removeNullValues = filterAttrs (n: v: v != null);
      #  ciOutputs = genAttrs defaultSystems (system: {
      #    flake = self.lib.removeNullValues {
      #      checks = ciMatrix "check" (self.checks.${system} or {});
      #      packages = ciMatrix "package" (ciPackagesFor system);
      #      hosts = ciMatrix "host" (ciHostsFor system);
      #    };
      #  });
      #};
    });
}
