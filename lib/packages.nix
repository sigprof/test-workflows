# The implementations of `flattenTree` and `filterPackages` were copied from
# https://github.com/numtide/flake-utils (just referencing that flake is not
# possible, because the NUR code prohibits all kinds of external URL access
# during evaluation, so there is no way to use an external library).
#
{...}: {
  packages = {
    flattenTree = tree: let
      op = sum: path: val: let
        pathStr = builtins.concatStringsSep "/" path;
      in
        if (builtins.typeOf val) != "set"
        then
          # ignore that value
          # builtins.trace "${pathStr} is not of type set"
          sum
        else if val ? type && val.type == "derivation"
        then
          # builtins.trace "${pathStr} is a derivation"
          # we used to use the derivation outPath as the key, but that crashes Nix
          # so fallback on constructing a static key
          (sum // {"${pathStr}" = val;})
        else if val ? recurseForDerivations && val.recurseForDerivations == true
        then
          # builtins.trace "${pathStr} is a recursive"
          # recurse into that attribute set
          (recurse sum path val)
        else
          # ignore that value
          # builtins.trace "${pathStr} is something else"
          sum;

      recurse = sum: path: val:
        builtins.foldl'
        (sum: key: op sum (path ++ [key]) val.${key})
        sum
        (builtins.attrNames val);
    in
      recurse {} [] tree;

    filterPackages = system: packages: let
      # Adopted from nixpkgs.lib
      inherit (builtins) listToAttrs concatMap attrNames;
      nameValuePair = name: value: {inherit name value;};
      filterAttrs = pred: set:
        listToAttrs (
          concatMap
          (name: let
            v = set.${name};
          in
            if pred name v
            then [(nameValuePair name v)]
            else [])
          (attrNames set)
        );

      # Everything that nix flake check requires for the packages output
      sieve = n: v:
        with v; let
          inherit (builtins) isAttrs;
          isDerivation = x: isAttrs x && x ? type && x.type == "derivation";
          isBroken = meta.broken or false;
          platforms = meta.platforms or null;
          badPlatforms = meta.badPlatforms or [];
        in
          # check for isDerivation, so this is independently useful of
          # flattenTree, which also does filter on derivations
          isDerivation v
          && !isBroken
          && ((platforms == null) || (builtins.elem system platforms))
          && !(builtins.elem system badPlatforms);
    in
      filterAttrs sieve packages;
  };
}
