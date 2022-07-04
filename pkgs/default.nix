{pkgs, ...}: {
  inherit (pkgs) hello firefox jq;
  nested = pkgs.lib.recurseIntoAttrs {
    inherit (pkgs) hello;
  };
}
