{self, ...}: let
  x = 1;
in {
  ciData = self.lib.ci.makeCiData self {
    config = {
      packages = {
        groups = [
          ["hello" "jq"]
        ];
        exclude = ["default"];
      };
      hosts = {
        groups = [
          ["example/.*"]
        ];
      };
    };
  };
}
