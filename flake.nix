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

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    comfyui-src = {
      url = "git+file:///home/deng/comfy/ComfyUI";
      flake = false;
    };
  };

  outputs =
    { nixpkgs, comfyui-src, ... }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;

        config = {
          allowUnfree = true;
          cudaSupport = true;
          permittedInsecurePackages = [ "cuda12.9-tensorrt-10.14.1.48" ];
          # Do not set cudaCapabilities while testing cache hits.
          # Custom capabilities change derivation hashes.
        };
      };

      py = pkgs.python3Packages;

      segmentAnything = py.buildPythonPackage rec {
        pname = "segment-anything";
        version = "1.0";
        format = "wheel";

        src = pkgs.fetchPypi {
          pname = "segment_anything";
          inherit version format;
          dist = "py3";
          python = "py3";
          abi = "none";
          platform = "any";
          hash = "sha256-hvZ9QXqRWCPDMCCY7/6QCLaIlFdyUXMQlWu0neDn8C4=";
        };

        doCheck = false;
      };

      /*
        comfyui = pkgs.callPackage ./package.nix {
             inherit comfyui-src;
             extra_deps =
               (with py; [
                 dill
                 matplotlib
                 numpy
                 opencv-python-headless
                 piexif
                 sam2
                 scikit-image
                 scipy
                 transformers
                 ultralytics
               ])
               ++ [
                 segmentAnything
               ];
           };
      */

      comfyui = pkgs.callPackage ./package.nix {
        inherit comfyui-src;
        extra_deps =
          (with py; [
            # Impact Pack module-load checks and FaceDetailer/SAMLoader support.
            opencv-python-headless
            piexif
            sam2
            scikit-image

            # Impact Subpack UltralyticsDetectorProvider support.
            dill
            ultralytics

            #benchmark custom_node
            pyyaml
            psutil

            #tensorrt custom_node
            onnx
            tensorrt
          ])
          ++ [
            segmentAnything
          ];

        extra_runtime_libs = [
          #tensorrt custom_node
          pkgs.cudaPackages.tensorrt
        ];
      };
    in
    {
      packages.${system} = {
        inherit comfyui;
        default = comfyui;
      };
    };
}
