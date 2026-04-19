{
  description = "FluidX3D - Extremely Fast 3D Computational Fluid Dynamics Lattice Boltzmann Solver";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Only build on Linux x86_64 for maximum performance
        shouldBuild = system == "x86_64-linux";

        # Source with bundled libraries excluded to prevent conflicts with nixpkgs
        filteredSrc = pkgs.lib.cleanSourceWith {
          src = ./.;
          name = "fluidx3d-src";
          filter = path: type:
            let
              relPath = pkgs.lib.removePrefix (toString ./. + "/") (toString path);
            in
            !(pkgs.lib.hasPrefix "src/OpenCL/lib" relPath ||
              pkgs.lib.hasPrefix "src/X11/lib" relPath ||
              pkgs.lib.hasPrefix "temp/" relPath ||
              pkgs.lib.hasPrefix "bin/" relPath ||
              pkgs.lib.hasPrefix ".git" relPath);
        };

      in {
        # Only provide packages on supported systems
        packages = if shouldBuild then {
          default = pkgs.stdenv.mkDerivation {
            pname = "FluidX3D";
            version = self.shortRev or "dev";

            # Filtered source excluding bundled libraries
            src = filteredSrc;

            # Use system libraries for true Nix-pure approach
            nativeBuildInputs = with pkgs; [
              gcc
              binutils
              ocl-icd
            ];

            buildInputs = with pkgs; [
              opencl-headers
              opencl-clhpp
              xorg.libX11
              xorg.libXrandr
            ];

            # Enable parallel building for maximum speed
            enableParallelBuilding = true;

            # Custom build process using makefile with proper variable overrides
            # Command-line arguments to make override target-specific assignments
            buildPhase = ''
              runHook preBuild

              # Pass library paths as make command-line arguments to override
              # the makefile's bundled library paths (-L./src/OpenCL/lib etc.)
              make Linux-X11 \
                LDFLAGS_OPENCL="-I${pkgs.opencl-clhpp}/include" \
                LDLIBS_OPENCL="-L${pkgs.ocl-icd}/lib -lOpenCL" \
                LDFLAGS_X11="-I${pkgs.xorg.libX11.dev}/include -I${pkgs.xorg.libXrandr.dev}/include" \
                LDLIBS_X11="-L${pkgs.xorg.libX11}/lib -lX11 -L${pkgs.xorg.libXrandr}/lib -lXrandr"

              runHook postBuild
            '';

            # Install phase
            installPhase = ''
              runHook preInstall
              mkdir -p $out/bin
              cp bin/FluidX3D $out/bin/
              runHook postInstall
            '';

            # Check phase with proper validation
            checkPhase = ''
              runHook preCheck
              echo "Running FluidX3D for 2 seconds with default settings..."
              timeout 2s $out/bin/FluidX3D && echo "FluidX3D executed successfully" || {
                exit_code=$?
                if [ $exit_code -eq 124 ]; then
                  echo "Timeout reached (expected for long-running simulation)"
                else
                  echo "FluidX3D failed with exit code $exit_code"
                  exit $exit_code
                fi
              }
              runHook postCheck
            '';

            # Metadata
            meta = with pkgs.lib; {
              description = "Extremely Fast 3D Computational Fluid Dynamics Lattice Boltzmann Solver";
              longDescription = ''
                FluidX3D is a high-performance 3D computational fluid dynamics solver
                using the Lattice Boltzmann Method. It features extreme optimization
                with OpenCL acceleration for maximum performance on modern hardware.
              '';
              homepage = "https://github.com/ProjectPhysX/FluidX3D";
              license = licenses.mit;
              platforms = [ "x86_64-linux" ];
              maintainers = with maintainers; [ ];
              mainProgram = "FluidX3D";
            };
          };
        } else {
          # Empty package set for unsupported systems
          default = pkgs.stdenv.mkDerivation {
            name = "FluidX3D-unsupported";
            buildCommand = ''
              echo "FluidX3D only supports x86_64-linux for maximum performance"
              exit 1
            '';
          };
        };

        # Development shell
        devShells = if shouldBuild then {
          default = pkgs.mkShell {
            inputsFrom = [ self.packages.${system}.default ];

            buildInputs = with pkgs; [
              cmake
              gdb
              valgrind
            ];

            shellHook = ''
              echo "FluidX3D Development Environment"
              echo "System: ${system}"
              echo "OpenCL Headers: ${pkgs.opencl-headers}"
              echo "Ready for compilation with system libraries"
            '';
          };
        } else {
          default = pkgs.mkShell {
            shellHook = ''
              echo "FluidX3D development shell only available on x86_64-linux"
              exit 1
            '';
          };
        };

        # Apps for easy execution
        apps = if shouldBuild then {
          default = {
            type = "app";
            program = "${self.packages.${system}.default}/bin/FluidX3D";
            meta.description = "Run FluidX3D CFD solver";
          };
        } else {
          default = {
            type = "app";
            program = "${pkgs.writeShellScript "fluidx3d-unsupported" ''
              echo "FluidX3D only supports x86_64-linux"
              exit 1
            ''}";
          };
        };
      }) // {
      # Overlays for NixOS integration (system-agnostic, outside eachDefaultSystem)
      overlays.default = final: prev: {
        FluidX3D = self.packages.${final.system}.default;
      };
    };
}
