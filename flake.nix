{
  description = "GeTax PP, Geneva personal tax return software";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      inherit (pkgs) lib;

      releases = lib.importJSON ./releases.json;
      latestYear = lib.last (lib.sort lib.lessThan (lib.attrNames releases));

      runtimeLibs = with pkgs; [
        gtk3
        glib
        cairo
        pango
        gdk-pixbuf
        atk
        webkitgtk_4_1
        libsecret
        libxtst
        libx11
        libGL
      ];

      mkGetax =
        year:
        { version, hash, ... }:
        pkgs.stdenvNoCC.mkDerivation {
          pname = "getax-pp-${year}";
          inherit version;

          # Upstream overwrites this URL in place on every point release.
          src = pkgs.fetchurl {
            url = "https://www.getax.ch/getaxpp/${year}/getax${year}.tar.gz";
            inherit hash;
          };

          nativeBuildInputs = [
            pkgs.makeWrapper
            pkgs.copyDesktopItems
          ];

          installPhase = ''
            runHook preInstall
            mkdir -p $out/share/getax-pp-${year} $out/share/icons/hicolor/32x32/apps
            # The bootstrap self-updater needs a writable install dir, so the main class is run directly.
            cp -r lib config model version.xml $out/share/getax-pp-${year}/
            icon=$(find config -iname 'mainframe32*' -o -iname 'mainframe16.gif' | head -1)
            [ -n "$icon" ] && cp "$icon" $out/share/icons/hicolor/32x32/apps/getax-${year}.''${icon##*.}

            # Without glib-networking the e-démarches login shows "TLS support is not available".
            makeWrapper ${pkgs.jdk17}/bin/java $out/bin/getax-${year} \
              --chdir $out/share/getax-pp-${year} \
              --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs} \
              --prefix XDG_DATA_DIRS : ${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}:${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name} \
              --prefix GIO_EXTRA_MODULES : ${pkgs.glib-networking}/lib/gio/modules \
              --set-default SSL_CERT_FILE ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt \
              --set-default GDK_BACKEND x11 \
              --run 'GETAX_HOME=''${GETAX_HOME:-$HOME}; mkdir -p "$GETAX_HOME"' \
              --add-flags '-Duser.home="$GETAX_HOME"' \
              --add-flags "-cp lib/getax-pp-cd.jar:lib/org.eclipse.swt.gtk.linux.x86_64.jar" \
              --add-flags "ch.dvbern.tax.ge.pp.presentation.cd.TaxmeGeLauncher"
            runHook postInstall
          '';

          desktopItems = [
            (pkgs.makeDesktopItem {
              name = "getax-${year}";
              desktopName = "GeTax ${year}";
              comment = "Déclaration d'impôt Genève ${year}";
              exec = "getax-${year}";
              icon = "getax-${year}";
              categories = [
                "Office"
                "Finance"
              ];
            })
          ];

          meta = {
            description = "Geneva personal tax return software (GeTax PP ${year})";
            homepage = "https://www.getax.ch/support/telecharger";
            license = lib.licenses.unfree;
            sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
            platforms = [ system ];
            mainProgram = "getax-${year}";
          };
        };

      getax = lib.mapAttrs' (year: r: lib.nameValuePair "getax-${year}" (mkGetax year r)) releases;

      update = pkgs.writeShellApplication {
        name = "getax-update";
        # nix comes from the caller: the store must be the caller's.
        runtimeInputs = with pkgs; [
          curl
          jq
          gnutar
          gzip
          gnused
        ];
        text = builtins.readFile ./update.sh;
      };
    in
    {
      packages.${system} = getax // {
        default = getax."getax-${latestYear}";
        inherit update;
      };

      apps.${system} = {
        default = {
          type = "app";
          program = lib.getExe getax."getax-${latestYear}";
          meta.description = "GeTax PP ${latestYear}";
        };
        update = {
          type = "app";
          program = lib.getExe update;
          meta.description = "Re-pin changed GeTax tarballs and add newly published years";
        };
      };

      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = lib.attrValues getax ++ [
          pkgs.lefthook
          pkgs.gitleaks
          pkgs.nixfmt
          pkgs.deadnix
          pkgs.statix
          pkgs.shfmt
          pkgs.shellcheck
          pkgs.actionlint
        ];
        shellHook = ''
          export GETAX_HOME="$PWD/data"
          [ -d .git ] && lefthook install >/dev/null
        '';
      };
    };
}
