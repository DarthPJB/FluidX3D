# AGENTS.md

## FluidX3D Packaging (NixOS)

### Critical: Use system libraries only
- Never assume bundled `src/OpenCL/lib` or `src/X11/lib` are used — they are filtered out in `cleanSourceWith`
- Always use nixpkgs: `opencl-clhpp`, `ocl-icd`, `xorg.libX11`, `xorg.libXrandr`
- Linking errors? Check if `LDFLAGS_OPENCL`/`LDLIBS_OPENCL` override makefile defaults correctly

### Build system integration
- Build is driven by upstream `makefile` — do not reimplement compilation logic
- Use `make Linux-X11` with explicit environment overrides:
  ```
  LDFLAGS_OPENCL="-I${pkgs.opencl-clhpp}/include" \
  LDLIBS_OPENCL="-L${pkgs.ocl-icd}/lib -lOpenCL" \
  LDFLAGS_X11="-I${pkgs.xorg.libX11.dev}/include -I${pkgs.xorg.libXrandr.dev}/include" \
  LDLIBS_X11="-L${pkgs.xorg.libX11}/lib -lX11 -L${pkgs.xorg.libXrandr}/lib -lXrandr"
  ```

### Versioning
- Version is `self.shortRev or "dev"` — expect "dev" in local dev builds due to uncommitted changes
- Do not assume git revision is available in local workspace; rely on `shortRev` only in clean clones

### Testing
- `checkPhase` uses `timeout 2s $out/bin/FluidX3D` — timeout (exit 124) is expected behavior
- No integration test suite exists; do not look for VTK output validation or simulation verification

### NixOS integration
- Overlay is defined as `final.pkgs.FluidX3D` — use this for systemPackages or services
- Only supports `x86_64-linux` — do not attempt to build on macOS or ARM

### Source filtering
- `src = ./.` is filtered to exclude:
  - `src/OpenCL/lib/`
  - `src/X11/lib/`
  - `temp/`
  - `bin/`
  - `.git/`
- Do not assume bundled headers in `src/OpenCL/include/` are used — they are ignored

### Dev workflow
- Use `nix develop` to enter dev shell with `gdb`, `valgrind`, `cmake`
- Do not run `make` directly in workspace — use `nix build .#default` or `nix run .#`

### Verification
- Run `nix flake check --all-systems` to validate structure
- Run `ldd result/bin/FluidX3D` to confirm all libraries are from `/nix/store/`

> This file replaces all prior flake.nix documentation. Trust the code, not the README.
