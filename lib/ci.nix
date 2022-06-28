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

      matrixForPerSystemAttrs = outputAttrs: outputName:
        genAttrs (attrNames outputAttrs) (system: let
          names = attrNames outputAttrs.${system};
          groupedNames = filterAndGroupNames names (ciData.${outputName} or {});
          items = map (list: {${outputName} = list;}) groupedNames;
        in
          optionalAttrs (items != []) {
            flake.${outputName}.item = items;
          });

      # Unfortunately, `nixosConfigurations` is not split by system name like
      # `packages` and `checks`.  Convert it to a similar form, so that the
      # same code could be used for the `hosts` CI items.
      addSystemToHost = name: value: {
        ${value.config.nixpkgs.system} = {${name} = value;};
      };
      hostEntryList = mapAttrsToList addSystemToHost (flake.nixosConfigurations or {});
      hosts = recursiveUpdateMany hostEntryList;
    in
      recursiveUpdateMany [
        ciData
        {matrix = matrixForPerSystemAttrs (flake.packages or {}) "packages";}
        {matrix = matrixForPerSystemAttrs (flake.checks or {}) "checks";}
        {matrix = matrixForPerSystemAttrs hosts "hosts";}
      ];
  };
}
