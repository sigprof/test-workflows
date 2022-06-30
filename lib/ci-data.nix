{self, ...}: {
  ciData = self.lib.ci.makeCiData self {
    config = {
      packages = {
        groups = [
          ["hello" "jq"]
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
