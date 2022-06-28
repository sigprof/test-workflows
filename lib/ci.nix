{
  self,
  nixpkgs,
  flake-utils,
  ...
}: let
  inherit (builtins) match foldl' filter;
  inherit (nixpkgs.lib) any genAttrs attrNames optionalAttrs;
  inherit (nixpkgs.lib) fixedWidthNumber groupBy sort mapAttrsToList;
  inherit (flake-utils.lib) defaultSystems;
  inherit (self.lib.attrsets) recursiveUpdateMany;
  inherit (self.lib.lists) findFirstIndex;
in {
  ci = {
    makeCiData = flake: ciData: let
      matchName = name: pattern: (match pattern name) != null;
      isNameInGroup = name: group: any (matchName name) group;
      isNameNotExcluded = excludeList: name: !(any (matchName name) excludeList);

      # Convert a list of names (strings) to a list of groups, where each group
      # is a list of names.
      #
      # Arguments:
      #   - `names` - list of names (strings) to process;
      #   - `config` - attribute set specifying the configuration.
      #
      # `config` may optionally have the following attributes:
      #
      #   - `exclude` - a list of regular expressions (strings).  If an input
      #     name matches any of these regular expressions, it is omitted from
      #     the result.
      #
      #   - `groups` - a list of group definitions, where each group definition
      #     is a list of regular expressions (strings).  If an input name
      #     matches any regular expression for a group, that name is placed
      #     into the corresponding group; if a name happens to match multiple
      #     groups, the first matching group is chosen.  If an input name does
      #     not match any groups, it is placed into a separate group by itself.
      #
      # Groups in the returned list are ordered according to the order of
      # corresponding definitions in `config.groups`; groups for unmatched
      # names are placed after all configured groups and sorted by the name.
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
      #   - `outputAttrs` - the per system attribute set of items to include in
      #     the job matrix;
      #   - `outputName` - the name of the attribute (used to get the config
      #     from `ciData` and to name the resulting matrix).
      #
      # Returns an attribute set structured like:
      #
      #     {
      #       ${system}.flake.${outputName}.item = [
      #         { ${outputName} = [ "name1" "name2" ]; }
      #         { ${outputName} = [ "name3 ]; }
      #       ];
      #     }
      #
      matrixForPerSystemAttrs = outputAttrs: outputName:
        genAttrs (attrNames outputAttrs) (system: let
          names = attrNames outputAttrs.${system};
          groupedNames = filterAndGroupNames names (ciData.${outputName} or {});
          items = map (list: {${outputName} = list;}) groupedNames;
        in
          optionalAttrs (items != []) {
            flake.${outputName}.item = items;
          });

      # `nixosConfigurations` is a flat attribute set; convert it to a per
      # system attribute set `hosts` similar to `packages` or `checks`, so that
      # the same functions could be used to process it.
      hosts = let
        addSystem = name: value: {
          ${value.config.nixpkgs.system} = {
            ${name} = value;
          };
        };
      in
        recursiveUpdateMany (mapAttrsToList addSystem (flake.nixosConfigurations or {}));
    in
      recursiveUpdateMany [
        ciData
        {matrix = matrixForPerSystemAttrs (flake.packages or {}) "packages";}
        {matrix = matrixForPerSystemAttrs (flake.checks or {}) "checks";}
        {matrix = matrixForPerSystemAttrs hosts "hosts";}
      ];
  };
}
