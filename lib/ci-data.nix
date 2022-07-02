{self, ...}: {
  ciData = self.lib.ci.makeCiData self {
    config = {
      packages = {
        groups = [
          ["hello" "jq" "nested[./]hello"]
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
