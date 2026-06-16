{
  nixConfig = {
    extra-substituters = [
      "https://cache.nixos-cuda.org"
      "https://nix-community.cachix.org"
    ];

    extra-trusted-public-keys = [
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;

        config = {
          allowUnfree = true;
          cudaSupport = true;

          # Do not set cudaCapabilities while testing cache hits.
          # Custom capabilities change derivation hashes.
        };
      };

      comfyui = pkgs.callPackage ./package.nix { };
    in
    {
      packages.${system} = {
        inherit comfyui;
        default = comfyui;
      };
    };
}
