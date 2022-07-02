{
  self,
  nixpkgs,
  ...
}: let
  inherit (builtins) filter match;
  inherit (nixpkgs.lib.attrsets) isDerivation;
  inherit (nixpkgs.lib.strings) concatMapStringsSep escapeNixIdentifier;
  inherit (nixpkgs.lib) any attrNames fixedWidthNumber genAttrs groupBy mapAttrsToList optionalAttrs sort;
  inherit (self.lib.attrsets) flattenAttrs recursiveUpdateMany;
  inherit (self.lib.lists) findFirstIndex;

  matchName = name: pattern: (match pattern name) != null;
  isNameInGroup = name: group: any (matchName name) group;
  isNameNotExcluded = excludeList: name: !(any (matchName name) excludeList);

  # Convert a list of names (strings) to a list of groups, where each group is
  # a list of names.
  #
  # Arguments:
  # - `names` - list of names (strings) to process;
  # - `config` - attribute set specifying the configuration.
  #
  # `config` may optionally have the following attributes:
  #
  # - `exclude` - a list of regular expressions (strings).  If an input name
  #   matches any of these regular expressions, it is omitted from the result.
  #
  # - `groups` - a list of group definitions, where each group definition is a
  #   list of regular expressions (strings).  If an input name matches any
  #   regular expression for a group, that name is placed into the
  #   corresponding group; if a name happens to match multiple groups, the
  #   first matching group is chosen.  If an input name does not match any
  #   groups, it is placed into a separate group by itself.
  #
  # Groups in the returned list are ordered according to the order of
  # corresponding definitions in `config.groups`; groups for unmatched names
  # are placed after all configured groups and sorted by the name.
  #
  filterAndGroupNames = names: config: let
    groups = config.groups or [];
    exclude = config.exclude or [];
    getGroupForName = name: let
      index = findFirstIndex (isNameInGroup name) null groups;
    in
      if index == null
      then "1/" + name
      else "0/" + (fixedWidthNumber 8 index);
    filteredNames = filter (isNameNotExcluded exclude) names;
    namesByGroup = groupBy getGroupForName filteredNames;
    sortedGroupNames = sort builtins.lessThan (attrNames namesByGroup);
  in
    map (groupName: namesByGroup.${groupName}) sortedGroupNames;

  # Generate a job matrix for a per system flake output attribute.
  #
  # Arguments:
  # - `jobClass` - `"flake"` for an normal flake build, `"nur"` for a NUR
  #   build (in this case a flake-like structure with `nurPackages` instead of
  #   `packages` will be passed instead of a real flake, and `nixpkgs` would be
  #   whatever has been passed to NUR);
  # - `jobName` - the name of the job (used to name the resulting matrix);
  # - `config` - CI configuration data for the job which contains rules to
  #   group and exclude items;
  # - `outputAttrs` - the per system attribute set of items to include in the
  #   job matrix.
  #
  # Returns an attribute set structured like:
  #
  #     {
  #       ${system}.${jobClass}.${jobName}.item = [
  #         { ${jobName} = [ "name1" "name2" ]; }
  #         { ${jobName} = [ "name3 ]; }
  #       ];
  #     }
  #
  matrixForPerSystemAttrs = jobClass: jobName: config: outputAttrs:
    genAttrs (attrNames outputAttrs) (system: let
      names = attrNames outputAttrs.${system};
      groupedNames = filterAndGroupNames names config;
      items = map (list: {${jobName} = list;}) groupedNames;
    in
      optionalAttrs (items != []) {
        ${jobClass}.${jobName}.item = items;
      });

  # Generate a per system `hosts` attribute set from a flake.
  #
  # The standard `nixosConfigurations` attribute set in a flake is flat, unlike
  # per system attribute sets like `packages` or `checks`. Produce a per system
  # attribute set containing the same configurations, so that functions that
  # can process a per system attribute set could be used with it.
  #
  flakeHosts = flake: let
    addSystem = name: value: {
      ${value.config.nixpkgs.system} = {
        ${name} = value;
      };
    };
  in
    recursiveUpdateMany (mapAttrsToList addSystem (flake.nixosConfigurations or {}));

  # Convert the nested attribute set from `flake.nurPackages` to a flat
  # attribute set which would be usable with `matrixForPerSystemAttrs`.
  #
  nurPackages = flake: let
    packages = flake.nurPackages or {};
    valueCond = _: value: isDerivation value;
    recurseCond = path: value: (path == []) || (value.recurseForDerivations or false);
    pathToName = path: concatMapStringsSep "." escapeNixIdentifier path;
  in
    genAttrs (attrNames packages) (system:
      flattenAttrs valueCond recurseCond pathToName packages.${system});

  # Generate the set of job matrices for the flake.
  #
  # Parameters:
  # - `matrixDesc` - the description of job matrices in the following format:
  #     {
  #       ${jobClass} = {
  #         ${jobName} = {
  #           config = {...};
  #           perSystemAttrs = {...};
  #         };
  #       };
  #     }
  #   where `config` is the CI configuration data for the job, and
  #   `perSystemAttrs` is a per system attribute set similar to `self.packages`
  #   or `self.checks` in a flake.
  #
  makeMatrix = matrixDesc: let
    matrixForJobClass = jobClass: jobClassDesc: let
      matrixForJob = jobName: jobDesc:
        matrixForPerSystemAttrs jobClass jobName jobDesc.config jobDesc.perSystemAttrs;
    in
      recursiveUpdateMany (mapAttrsToList matrixForJob jobClassDesc);
  in
    recursiveUpdateMany (mapAttrsToList matrixForJobClass matrixDesc);

  # Generate CI job matrix data for the flake.
  #
  # Arguments:
  # - `flake` - the flake to generate the data for;
  # - `ciData` - the `config` part of CI data.
  #
  # The expected structure of the `ciData` argument is:
  #     {
  #       config = {
  #         packages = {       # config for the `flake.packages` job
  #           groups = [       # groups determine which packages are built together
  #             ["pkg1"]       # this may be used to influence the job order
  #             ["pkg2", "pkg3"] # the specified packages get built in a single job
  #             ["pkg-.*"]     # extended regular expressions can be used
  #           ];
  #           exclude = [      # some packages can be excluded from CI builds
  #             "badpkg1"      # full name match
  #             "many-bad-.*"  # extended regular expressions can be used
  #           ];
  #         };
  #         checks = {         # config for the `flake.checks` job
  #           ...              # the same options as above are supported
  #         };
  #         hosts = {          # config for the `flake.hosts` job (builds `nixosConfigurations`)
  #           ...              # the same options as above are supported
  #         };
  #       };
  #       # any other keys will be copied to the output value
  #     }
  #
  # Returns a nested attribute set structured like:
  #     {
  #       config = {...};      # copied from the `ciData` argument
  #       matrix = {           # generated by `makeCiData`
  #         "x86_64-linux" = { # repeated for every supported system value
  #           flake = {        # this key and the nested one form the CI job name
  #             packages = {   # this value is the CI job matrix
  #               item = [     # this is a matrix dimension
  #                 {          # this is a matrix value for a job instance
  #                   packages = ["pkg1"];
  #                 }          # this job instance builds a single package
  #                 {          # this is a matrix value for another job instance
  #                   packages = ["pkg2", "pkg3"];
  #                 }          # this job instance builds a group of packages
  #               ];
  #             };
  #             hosts = {      # another job matrix
  #               item = [     # the matrix dimension name is the same
  #                 {
  #                   hosts = "host1"; # but the inner key is different
  #                 }          # this job instance builds a NixOS configuration
  #               ];
  #             };
  #           }
  #         };
  #         "x86_64-darwin" = {...}; # the same structure as above
  #       };
  #     }
  #
  # This matrix structure assumes that a separate set of CI jobs is defined for
  # every supported `system` value (the “reusable workflow” feature can be used
  # to make this work for multiple `system` types without actually duplicating
  # the workflow definition).  The Nix code can generate matrix for all
  # `system` values supported by Nix, then the CI jobs can use the subset of
  # these values which are supported by CI.
  #
  makeCiData = flake: ciData: let
    config = ciData.config or {};
  in
    recursiveUpdateMany [
      ciData
      {
        matrix = makeMatrix {
          flake.packages = {
            perSystemAttrs = flake.packages or {};
            config = config.packages or {};
          };
          flake.checks = {
            perSystemAttrs = flake.checks or {};
            config = config.checks or {};
          };
          flake.hosts = {
            perSystemAttrs = flakeHosts flake;
            config = config.hosts or {};
          };
          nur.nurPackages = {
            perSystemAttrs = nurPackages flake;
            config = config.nurPackages or config.packages or {};
          };
        };
      }
    ];
in {
  ci = {
    inherit makeCiData;
  };
}
