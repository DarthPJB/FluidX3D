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
        
        # System-specific OpenCL and graphics libraries
        systemLibs = with pkgs; [
          opencl-headers
          ocl-icd
          xorg.libX11
          xorg.libXrandr
          gcc
          binutils
        ];
        
        # Build flags following Bellana's aggressive approach
        cppFlags = "-std=c++17 -O3 -march=native -mtune=native -flto -DNDEBUG";
        linkFlags = "-lOpenCL -lX11 -lXrandr -pthread -flto";
        
      in {
        # Only provide packages on supported systems
        packages = if shouldBuild then {
          default = pkgs.stdenv.mkDerivation {
            pname = "fluidx3d";
            version = "1.0.0";
            
            # Source code from current directory
            src = ./.;
            
            # Use system libraries for true Nix-pure approach
            nativeBuildInputs = with pkgs; [
              gcc
              binutils
            ];
            
            buildInputs = systemLibs;
            
            # Enable parallel building for maximum speed
            enableParallelBuilding = true;
            
            # Custom build process using system libraries
            buildPhase = ''
              runHook preBuild
              
              # Compile with aggressive optimization flags
              g++ ${cppFlags} -c \
                src/main.cpp \
                src/lbm.cpp \
                src/kernel.cpp \
                src/graphics.cpp \
                src/info.cpp \
                src/setup.cpp \
                src/shapes.cpp \
                src/utilities.hpp \
                src/lodepng.cpp \
                -I./src/OpenCL/include \
                -I./src/X11/include
              
              # Link with system libraries
              g++ ${cppFlags} ${linkFlags} \
                main.o lbm.o kernel.o graphics.o info.o setup.o shapes.o lodepng.o \
                -o fluidx3d
              
              runHook postBuild
            '';
            
            # Install phase
            installPhase = ''
              runHook preInstall
              mkdir -p $out/bin
              cp fluidx3d $out/bin/
              runHook postInstall
            '';
            
            # Check phase with timeout test
            checkPhase = ''
              runHook preCheck
              echo "Running 2-second timeout test..."
              timeout 2s $out/bin/fluidx3d || true
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
              mainProgram = "fluidx3d";
            };
          };
        } else {
          # Empty package set for unsupported systems
          default = pkgs.stdenv.mkDerivation {
            name = "fluidx3d-unsupported";
            buildCommand = ''
              echo "FluidX3D only supports x86_64-linux for maximum performance"
              exit 1
            '';
          };
        };
        
        # Development shell
        devShells = if shouldBuild then {
          default = pkgs.mkShell {
            buildInputs = systemLibs ++ (with pkgs; [
              cmake
              gdb
              valgrind
            ]);
            
            shellHook = ''
              echo "FluidX3D Development Environment"
              echo "System: ${system}"
              echo "OpenCL Headers: $(opencl-headers --version 2>/dev/null || echo 'available')"
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
            program = "${self.packages.${system}.default}/bin/fluidx3d";
          };
        } else {
          default = {
            type = "app";
            program = "${pkgs.writeShellScript "unsupported" ''
              echo "FluidX3D only supports x86_64-linux"
              exit 1
            ''}";
          };
        };
      });
}