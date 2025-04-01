final: prev: {
  ipmi-fan-control = final.rustPlatform.buildRustPackage {
    pname = "ipmi-fan-control";
    version = "0.1.0"; # Update with your actual version

    src = ../.;

    cargoLock = {
      lockFile = ../Cargo.lock;
    };

    nativeBuildInputs = with final; [
      pkg-config
      clang
      llvmPackages_latest.libclang
    ];

    buildInputs = with final; [
      freeipmi
    ];

    # Environment variables for the build
    LIBCLANG_PATH = final.lib.makeLibraryPath [final.llvmPackages_latest.libclang.lib];

    # Add bindgen flags to help find the headers
    BINDGEN_EXTRA_CLANG_ARGS =
      # Includes normal include path
      (builtins.map (a: ''-I"${a}/include"'') [
        # add dev libraries here (e.g. final.libvmi.dev)
        final.glibc.dev
      ])
      # Includes with special directory paths
      ++ [
        ''-I"${final.llvmPackages_latest.libclang.lib}/lib/clang/${final.llvmPackages_latest.libclang.version}/include"''
        ''-I"${final.glib.dev}/include/glib-2.0"''
        ''-I${final.glib.out}/lib/glib-2.0/include/''
      ];

    # Add runtime dependencies to the library path
    postFixup = ''
      patchelf --set-rpath "${final.lib.makeLibraryPath [final.freeipmi]}" $out/bin/*
    '';
  };
}
