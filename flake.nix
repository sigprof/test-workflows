{
  description = "Test flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
    flake-utils.url = "github:numtide/flake-utils";

    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    pre-commit-hooks.inputs.nixpkgs.follows = "nixpkgs";
    pre-commit-hooks.inputs.flake-utils.follows = "flake-utils";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    flake-utils,
    pre-commit-hooks,
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
    })
    // (
      let
        checkedSystems = with flake-utils.lib.system; [
          x86_64-linux
          x86_64-darwin
          aarch64-linux
          aarch64-darwin
          # No `i686-linux` because `pre-commit-hooks` does not evaluate
        ];
      in
        flake-utils.lib.eachSystem checkedSystems (system: {
          checks =
            {
              pre-commit = pre-commit-hooks.lib.${system}.run {
                src = ./.;
                hooks = {
                  alejandra.enable = true;
                };
              };
            }
            // nixpkgs.lib.optionalAttrs (self.packages.${system} ? default) {
              default-package = self.packages.${system}.default;
            };
        })
    )
    // (let
      system = flake-utils.lib.system.x86_64-linux;
    in {
      nixosConfigurations = {
        #"example/minimal" = nixpkgs.lib.nixosSystem {
        #  inherit system;
        #  modules = [
        #    {
        #      system.stateVersion = "22.05";
        #      networking.hostName = "minimal";
        #      fileSystems."/".device = "/dev/sda1";
        #      boot.loader.grub.device = "/dev/sda";
        #    }
        #  ];
        #};
        #"example/minimal2" = nixpkgs.lib.nixosSystem {
        #  inherit system;
        #  modules = [
        #    {
        #      system.stateVersion = "22.05";
        #      networking.hostName = "minimal2";
        #      fileSystems."/".device = "/dev/sda1";
        #      boot.loader.grub.device = "/dev/sda";
        #    }
        #  ];
        #};
      };
      lib = import ./lib inputs;
    });
}
