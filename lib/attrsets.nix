{nixpkgs, ...}: let
  inherit (nixpkgs.lib.attrsets) filterAttrs;
in {
  removeNullsFromAttrs = filterAttrs (n: v: v != null);
}
