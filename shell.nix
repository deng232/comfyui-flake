# shell.nix
#
# Use:
#   nix-shell
#   ./result/bin/comfyui --listen 127.0.0.1 --port 8188
#
# This file only provides runtime/system libraries.

{
  pkgs ? import <nixpkgs> {
    config.allowUnfree = true;
  },
}:

let
  libPath = pkgs.lib.makeLibraryPath [
    pkgs.stdenv.cc.cc.lib
    pkgs.zlib
    pkgs.zstd
    pkgs.openssl
    pkgs.curl

    pkgs.libGL
    pkgs.glib
    pkgs.xorg.libX11
    pkgs.xorg.libXext
    pkgs.xorg.libXi
    pkgs.xorg.libXrender
    pkgs.xorg.libXrandr
    pkgs.xorg.libXcursor
    pkgs.xorg.libSM
    pkgs.xorg.libICE
  ];
in
pkgs.mkShell {
  packages = with pkgs; [
    git
    git-lfs
  ];

  shellHook = ''
    export LD_LIBRARY_PATH="${libPath}:/run/opengl-driver/lib:/run/opengl-driver-32/lib:$LD_LIBRARY_PATH"
    export CUDA_PATH=/run/opengl-driver

    echo "System ComfyUI shell loaded."
    echo "Build Python package separately with:"
    echo "  nix-build default.nix"
    echo
    echo "Run:"
    echo "  ./result/bin/comfyui --listen 127.0.0.1 --port 8188"
  '';
}
