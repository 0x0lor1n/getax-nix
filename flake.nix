{
  description = "GeTax PP 2025, Geneva personal tax return software";

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

      getax = pkgs.stdenvNoCC.mkDerivation {
        pname = "getax-pp";
        version = "2025-1.04";

        # Upstream overwrites this URL in place on every point release.
        src = pkgs.fetchurl {
          url = "https://www.getax.ch/getaxpp/2025/getax2025.tar.gz";
          hash = "sha256-AWKdRZreOw0HphcxEO+de++Yi5CC+2QFr/GOAgtA2o0=";
        };

        nativeBuildInputs = [
          pkgs.makeWrapper
          pkgs.copyDesktopItems
        ];

        installPhase = ''
          runHook preInstall
          mkdir -p $out/share/getax-pp-2025 $out/share/icons/hicolor/32x32/apps
          # The bootstrap self-updater needs a writable install dir, so the main class is run directly.
          cp -r lib config model version.xml $out/share/getax-pp-2025/
          icon=$(find config -iname 'mainframe32*' -o -iname 'mainframe16.gif' | head -1)
          [ -n "$icon" ] && cp "$icon" $out/share/icons/hicolor/32x32/apps/getax.''${icon##*.}

          # Without glib-networking the e-démarches login shows "TLS support is not available".
          makeWrapper ${pkgs.jdk17}/bin/java $out/bin/getax-2025 \
            --chdir $out/share/getax-pp-2025 \
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
            name = "getax-2025";
            desktopName = "GeTax 2025";
            comment = "Déclaration d'impôt Genève 2025";
            exec = "getax-2025";
            icon = "getax";
            categories = [
              "Office"
              "Finance"
            ];
          })
        ];

        meta = {
          description = "Geneva personal tax return software (GeTax PP 2025)";
          homepage = "https://www.getax.ch/support/telecharger";
          license = lib.licenses.unfree;
          sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
          platforms = [ system ];
          mainProgram = "getax-2025";
        };
      };
    in
    {
      packages.${system} = {
        default = getax;
        getax-2025 = getax;
      };

      apps.${system}.default = {
        type = "app";
        program = lib.getExe getax;
        meta.description = getax.meta.description;
      };

      # GeTax writes to $GETAX_HOME/GeTax2025 (default $HOME); the shell keeps it next to the flake.
      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = [
          getax
          pkgs.lefthook
          pkgs.gitleaks
        ];
        shellHook = ''
          export GETAX_HOME="$PWD/data"
          [ -d .git ] && lefthook install >/dev/null
        '';
      };
    };
}
