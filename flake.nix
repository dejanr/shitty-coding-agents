{
  description = "shitty-coding-agents devenv";

  inputs = {
    devenv-root = {
      url = "file+file:///dev/null";
      flake = false;
    };

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    devenv.url = "github:cachix/devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
    devenv.inputs.flake-parts.follows = "flake-parts";

    demo-it = {
      url = "git+ssh://git@github.com/dejanr/demo-it.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      flake-parts,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.devenv.flakeModule ];

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      perSystem =
        { pkgs, ... }:
        let
          demoItPackage = pkgs.lib.attrByPath [ "demo-it" "packages" pkgs.system "default" ] null inputs;
        in
        {
          devenv.shells.default = {
            name = "shitty-coding-agents";
            imports = [ ./devenv.nix ];
            packages = pkgs.lib.optionals (demoItPackage != null) [ demoItPackage ];
          };
        };
    };
}
