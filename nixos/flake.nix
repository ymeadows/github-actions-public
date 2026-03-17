{
  description = "YMeadows Github Actionss";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = (
          import nixpkgs {
            inherit system;

            config.allowUnfree = true;
          }
        );
      in
      {
        nixosModules.buildDeps =
          { config, ... }:
          {
            services.ym-github-runner.extraPackages = with pkgs; [
              gzip
              trivy
              nix-update
              jq
              skopeo
            ];
          };
      }
    );
}
