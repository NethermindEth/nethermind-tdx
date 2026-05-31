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
      # We previously patched mkosi to force `zstd -T1`, but empirical
      # testing showed `-T0` and `-T1` produce byte-identical output on
      # the same zstd version. Cross-host divergence comes from mkosi's
      # sandbox falling back to /usr/bin/zstd, which differs between Lima
      # Debian (1.5.7) and Ubuntu 24.04 (1.5.5). The fix is to inject
      # `--extra-search-path` pointing at the nix zstd via
      # scripts/with_zstd_shim.sh — see that file for details. The
      # overrideAttrs.postPatch approach broke the nixpkgs wrapping that
      # generates `mkosi-sandbox`, so we keep mkosi-unwrapped vanilla.
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
            zstd
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
    devShells = builtins.listToAttrs (map (system: let
      pkgsForSystem = import nixpkgs {inherit system;};
    in {
      name = system;
      # `pkgsForSystem.zstd` is exposed at the devShell level so the path is
      # resolvable from `which zstd` inside `nix develop`; scripts/with_zstd_shim.sh
      # uses it to inject --extra-search-path into mkosi so mkosi's bwrap
      # sandbox uses the SAME zstd binary on every host (otherwise mkosi
      # falls back to /usr/bin/zstd, which varies between Lima Debian
      # trixie and the GH Ubuntu runner — causing different initrd bytes).
      value.default = pkgs.mkShell {
        nativeBuildInputs = [(mkosi system) measured-boot measured-boot-gcp pkgsForSystem.zstd];
        shellHook = ''
          mkdir -p mkosi.packages mkosi.cache mkosi.builddir ~/.cache/mkosi
          touch mkosi.builddir/debian-backports.sources
        '';
      };
    }) ["x86_64-linux" "aarch64-linux"]);
  };
}
