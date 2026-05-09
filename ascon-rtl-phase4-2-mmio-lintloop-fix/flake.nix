{
  description = "Bus-agnostic ASCON RTL core, Phase 0/1 bring-up";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    ascon-c = {
      url = "github:ascon/ascon-c";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, ascon-c }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f (import nixpkgs { inherit system; }));
    in {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          ASCON_C_DIR = ascon-c;
          packages = with pkgs; [
            gcc
            git
            gnumake
            iverilog
            python3
            verilator
            yosys
            gtkwave
          ] ++ lib.optional (pkgs ? verible) verible;

          shellHook = ''
            echo "ascon-rtl-core dev shell"
            echo "  ASCON_C_DIR=$ASCON_C_DIR"
            echo "  make vectors-ascon-c"
            echo "  make sim-iverilog"
            echo "  make synth-yosys"
          '';
        };
      });

      checks = forAllSystems (pkgs: {
        phase1-vectors-from-ascon-c = pkgs.runCommand "ascon-rtl-core-phase1-vectors" {
          nativeBuildInputs = [ pkgs.gcc pkgs.gnumake ];
          ASCON_C_DIR = ascon-c;
          src = self;
        } ''
          cp -r $src repo
          chmod -R u+w repo
          cd repo
          make vectors-ascon-c
          test -s sim/generated/ascon_perm_vectors.vh
          touch $out
        '';

        phase1-iverilog = pkgs.runCommand "ascon-rtl-core-phase1-iverilog" {
          nativeBuildInputs = [ pkgs.gcc pkgs.gnumake pkgs.iverilog ];
          ASCON_C_DIR = ascon-c;
          src = self;
        } ''
          cp -r $src repo
          chmod -R u+w repo
          cd repo
          make vectors-ascon-c
          make sim-iverilog
          touch $out
        '';
      });
    };
}
