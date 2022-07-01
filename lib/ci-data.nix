{self, ...}: {
  ciData = self.lib.ci.makeCiData self {
    config = {
      packages = {
        groups = [
          ["hello" "jq" "nested[./]hello"]
        ];
        exclude = ["default"];
      };
      nurPackages = self.lib.ciData.config.packages;
      hosts = {
        groups = [
          ["example/.*"]
        ];
      };
    };
  };
}
