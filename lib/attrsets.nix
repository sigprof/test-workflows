{nixpkgs, ...}: let
  inherit (nixpkgs.lib.attrsets) filterAttrs;
in {
  attrsets = {
    removeNullsFromAttrs = filterAttrs (n: v: v != null);
  };
}
