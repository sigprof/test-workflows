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
      matchName = name: pattern:
        if hasPrefix "regex:" pattern
        then (match (removePrefix "regex:" pattern) name) != null
        else name == pattern;
      isNameInGroup = name: group: any (matchName name) group;
      isNameNotExcluded = excludeList: name: !(any (matchName name) excludeList);

      packageItemList = system: let
        flakePackageNames = attrNames flake.packages.${system};
        groups = ciData.packages.groups or [];
        exclude = ciData.packages.exclude or [];
        packageGroupName = name: let
          index = findFirstIndex (isNameInGroup name) null groups;
        in
          if index == null
          then "1/" + name
          else "0/" + (fixedWidthNumber 8 index);
        filteredPackageNames = filter (isNameNotExcluded exclude) flakePackageNames;
        packagesByGroup = groupBy packageGroupName filteredPackageNames;
        sortedGroupNames = sort builtins.lessThan (attrNames packagesByGroup);
        makePackageItem = groupName: {packages = packagesByGroup.${groupName};};
      in
        map makePackageItem sortedGroupNames;

      packageData = genAttrs (attrNames flake.packages) (system: let
        packageItems = packageItemList system;
      in
        optionalAttrs (packageItems != []) {
          flake.packages.item = packageItems;
        });

      hostNames = attrNames flake.nixosConfigurations;
      hostExclude = ciData.hosts.exclude or [];
      filteredHostNames = filter (isNameNotExcluded hostExclude) hostNames;
      hostSystem = hostName: flake.nixosConfigurations.${hostName}.config.nixpkgs.system;
      hostsBySystem = groupBy hostSystem filteredHostNames;
      makeHostItemsForSystem = system:
        map (hostName: {hosts = [hostName];}) hostsBySystem.${system};
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
        {matrix = hostData;}
      ];
  };
}
