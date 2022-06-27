{
  self,
  nixpkgs,
  flake-utils,
  ...
}: let
  inherit (builtins) match foldl' filter;
  inherit (nixpkgs.lib) any all isAttrs genAttrs attrNames filterAttrs optionalAttrs;
  inherit (nixpkgs.lib) hasPrefix removePrefix fixedWidthNumber groupBy sort;
  inherit (flake-utils.lib) defaultSystems;
  inherit (self.lib.attrsets) recursiveUpdateMany;
  inherit (self.lib.lists) findFirstIndex;
in {
  ci = {
    makePackageChecks = flake: system: let
      inherit (nixpkgs.lib) mapAttrs' nameValuePair;
      packages = flake.packages.${system} or {};
    in
      mapAttrs' (n: v: nameValuePair ("package/" + n) v) packages;

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

      matrixForPerSystemOutput = outputName:
        genAttrs (attrNames flake.${outputName}) (system: let
          names = attrNames flake.${outputName}.${system};
          groupedNames = filterAndGroupNames names (ciData.${outputName} or {});
          items = map (list: {${outputName} = list;}) groupedNames;
        in
          optionalAttrs (items != []) {
            flake.${outputName}.item = items;
          });

      packageData = matrixForPerSystemOutput "packages";
      checkData = matrixForPerSystemOutput "checks";

      hostNames = attrNames flake.nixosConfigurations;
      hostSystem = hostName: flake.nixosConfigurations.${hostName}.config.nixpkgs.system;
      hostsBySystem = groupBy hostSystem hostNames;
      makeHostItemsForSystem = system: let
        groupedHosts = filterAndGroupNames hostsBySystem.${system} (ciData.hosts or {});
      in
        map (hosts: {inherit hosts;}) groupedHosts;
      hostData = genAttrs (attrNames hostsBySystem) (system: let
        hostItems = makeHostItemsForSystem system;
      in
        optionalAttrs (hostItems != []) {
          flake.hosts.item = hostItems;
        });
    in
      recursiveUpdateMany [
        ciData
        {matrix = packageData;}
        {matrix = checkData;}
        {matrix = hostData;}
      ];
  };
}
