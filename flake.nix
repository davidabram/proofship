{
  description = "Proofship";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    bend-src = {
      url = "github:bendlang/bend/0b7e2b11c1054f5d0f4eb955cadb47997ef1115d";
      flake = false;
    };
  };

  outputs = { nixpkgs, bend-src, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          cudaSupport = true;
          cudaCapabilities = [ "8.9" ];
        };
      };

      cuda = pkgs.cudaPackages_12_9;

      cudaToolkit = pkgs.symlinkJoin {
        name = "cuda-toolkit-12.9";
        paths = [
          cuda.cudatoolkit
          cuda.cuda_nvrtc
          cuda.cuda_cudart
          cuda.cuda_nvcc
        ];
        postBuild = ''
          if [ -d "$out/lib64" ] && [ ! -e "$out/lib" ]; then
            ln -s lib64 "$out/lib"
          fi
          if [ -d "$out/lib" ] && [ ! -e "$out/lib64" ]; then
            ln -s lib "$out/lib64"
          fi
        '';
      };

      bend = pkgs.runCommand "bend-2" {
        nativeBuildInputs = [ pkgs.makeWrapper ];
      } ''
        mkdir -p "$out/bin" "$out/share/bend"
        cp -R ${bend-src}/. "$out/share/bend/"
        makeWrapper ${pkgs.bun}/bin/bun "$out/bin/bend" \
          --add-flags "$out/share/bend/bend2/main.ts"
      '';
    in {
      packages.${system} = {
        bend = bend;
        default = bend;
      };

      devShells.${system} = {
        default = pkgs.mkShell {
          packages = [
            bend
            pkgs.bun
            pkgs.clang_19
            pkgs.pkg-config
            pkgs.xorg.libX11
            pkgs.alsa-lib
            cudaToolkit
          ];

          shellHook = ''
            export CUDA_HOME="${cudaToolkit}"
            export CUDA_PATH="$CUDA_HOME"
            export CC=clang

            export NIX_CFLAGS_COMPILE="-I${cudaToolkit}/include -I${pkgs.xorg.libX11.dev}/include -I${pkgs.alsa-lib.dev}/include ''${NIX_CFLAGS_COMPILE:-}"
            export NIX_LDFLAGS="-L${cudaToolkit}/lib64 -L${cudaToolkit}/lib -L${pkgs.xorg.libX11}/lib -L${pkgs.alsa-lib}/lib ''${NIX_LDFLAGS:-}"
            export LD_LIBRARY_PATH="${cudaToolkit}/lib64:${cudaToolkit}/lib:${pkgs.xorg.libX11}/lib:${pkgs.alsa-lib}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
            if [ -d /run/opengl-driver/lib ]; then
              export NIX_LDFLAGS="-L/run/opengl-driver/lib $NIX_LDFLAGS"
              export LD_LIBRARY_PATH="/run/opengl-driver/lib:$LD_LIBRARY_PATH"
            fi
          '';
        };
      };
    };
}
