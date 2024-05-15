{ pkgs ? import <nixpkgs> {} }:
  pkgs.mkShell {
    nativeBuildInputs = [
                # compiler
          
pkgs.opencl-headers
pkgs.gcc
          # Debugger
          pkgs.gdb
          # Build System
          pkgs.cmake
          pkgs.gnumake
          # Development libraries
          pkgs.xorg.libX11
          pkgs.xorg.libX11.dev
          pkgs.xorg.libXcursor.dev
          pkgs.xorg.xinput
          pkgs.xorg.libXrandr
          pkgs.xorg.libXinerama.dev
          pkgs.xorg.libXi
          pkgs.xorg.libXext.dev
          pkgs.glfw3
          pkgs.libGL

    pkgs.cudatoolkit
    pkgs.linuxPackages.nvidia_x11

          # figlet for attractive messages
          pkgs.figlet

    ];
    buildInputs = with pkgs; [
       pkgs.ocl-icd
       pkgs.cudatoolkit
    ];
   shellHook = ''
       export OCL_PATH=${pkgs.ocl-icd}
       export CUDA_PATH=${pkgs.cudatoolkit}
       export LD_LIBRARY_PATH=${pkgs.linuxPackages.nvidia_x11}/lib:${pkgs.ncurses5}/lib:/run/opengl-driver/lib:${pkgs.ocl-icd}/lib
		  export EXTRA_LDFLAGS="-L/lib -L${pkgs.linuxPackages.nvidia_x11}/lib"
		  export EXTRA_CCFLAGS="-I/usr/include"
            figlet "hello shell"
   '';     

}
