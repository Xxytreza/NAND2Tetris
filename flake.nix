{
  description = "Verilog development environment";

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
            # Verilog tools
            iverilog        # Icarus Verilog simulator
            gtkwave         # Waveform viewer
            verilator       # High-performance Verilog simulator
            yosys           # Synthesis tool
            
            # Build tools
            gnumake
          ];
        };
      });
}
