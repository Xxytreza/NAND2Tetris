{
  description = "NAND2Tetris - From nand to deep learning: design an AI accelerator";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            verible
            python3
            python3Packages.pip
            python3Packages.virtualenv
            bazel
            gcc
            gnumake
          ];
        };
      });
}
