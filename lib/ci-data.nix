{self, ...}: {
  ciData = self.lib.ci.makeCiData self {
    config = {
      checks = {
        setup = ["pre-commit"];
      };
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
