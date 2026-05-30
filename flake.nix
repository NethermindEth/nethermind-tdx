{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = {
    self,
    nixpkgs,
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};
    reprepro = pkgs.stdenv.mkDerivation rec {
      name = "reprepro-${version}";
      version = "4.16.0";

      src = pkgs.fetchurl {
        url =
          "https://alioth.debian.org/frs/download.php/file/"
          + "4109/reprepro_${version}.orig.tar.gz";
        sha256 = "14gmk16k9n04xda4446ydfj8cr5pmzsmm4il8ysf69ivybiwmlpx";
      };

      nativeBuildInputs = [pkgs.makeWrapper];
      buildInputs =
        pkgs.lib.singleton (pkgs.gpgme.override {gnupg = pkgs.gnupg;})
        ++ (with pkgs; [db libarchive bzip2 xz zlib]);

      postInstall = ''
        wrapProgram "$out/bin/reprepro" --prefix PATH : "${pkgs.gnupg}/bin"
      '';
    };
    measured-boot = pkgs.buildGoModule {
      pname = "measured-boot";
      version = "main";
      src = pkgs.fetchFromGitHub {
        owner = "flashbots";
        repo = "measured-boot";
        rev = "v1.2.0";
        sha256 = "sha256-FjzJ6UQYyrM+U3OCMBpzd1wTxlikA5LI+NKrylGlG3c=";
      };
      vendorHash = "sha256-NrZjORe/MjfbRDcuYVOGjNMCo1JGWvJDNVEPojI3L/g=";
    };
    measured-boot-gcp = pkgs.buildGoModule {
      pname = "measured-boot-gcp";
      version = "main";
      src = pkgs.fetchFromGitHub {
        owner = "flashbots";
        repo = "dstack-mr-gcp";
        rev = "3d718ab28599ea0c05e65d0f742fdee9fc17a5c7";
        sha256 = "sha256-KFo9wcQuG98Hi4mlMr5VS6D6/STW7jzZ9y1DyqsI820=";
      };
      vendorHash = "sha256-MxOQSXLAbWC1SOCPzPrNcU20WElbe7eUVdCLTutSYM8=";
    };
    mkosi = system: let
      pkgsForSystem = import nixpkgs {inherit system;};
      # Wrap zstd to force -T1 for reproducible compression. mkosi's
      # compressor_command hardcodes `-T0` (use all CPU threads), so the
      # same source produces different (but valid) compressed bytes on a
      # 12-core Azure host vs a 4-core CI runner. The nix-store mkosi
      # binary rewrites PATH on entry, so a host-side PATH shim is
      # ineffective — we have to swap the dep at the nix-derivation level.
      zstd-shim = pkgsForSystem.writeShellScriptBin "zstd" ''
        new_args=()
        for arg in "$@"; do
          case "$arg" in
            -T*|--threads=*) new_args+=("-T1") ;;
            *)               new_args+=("$arg") ;;
          esac
        done
        exec ${pkgsForSystem.zstd}/bin/zstd "''${new_args[@]}"
      '';
      mkosi-unwrapped = pkgsForSystem.mkosi.override {
        extraDeps = with pkgsForSystem;
          [
            apt
            dpkg
            gnupg
            debootstrap
            squashfsTools
            dosfstools
            e2fsprogs
            mtools
            mustache-go
            cryptsetup
            gptfdisk
            util-linux
            zstd-shim
            which
            qemu-utils
            parted
            unzip
            jq
          ]
          ++ [reprepro];
      };
    in
      # Create a wrapper script that runs mkosi with unshare
      # Unshare is needed to create files owned by multiple uids/gids
      pkgsForSystem.writeShellScriptBin "mkosi" ''
        exec ${pkgsForSystem.util-linux}/bin/unshare \
          --map-auto --map-current-user \
          --setuid=0 --setgid=0 \
          -- \
          env PATH="$PATH" \
          ${mkosi-unwrapped}/bin/mkosi "$@"
      '';
  in {
    devShells = builtins.listToAttrs (map (system: {
      name = system;
      value.default = pkgs.mkShell {
        nativeBuildInputs = [(mkosi system) measured-boot measured-boot-gcp];
        shellHook = ''
          mkdir -p mkosi.packages mkosi.cache mkosi.builddir ~/.cache/mkosi
          touch mkosi.builddir/debian-backports.sources
        '';
      };
    }) ["x86_64-linux" "aarch64-linux"]);
  };
}
