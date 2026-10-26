# getax-nix

Nix flake for [GeTax PP 2025](https://www.getax.ch/support/telecharger), the
Geneva personal tax return software (déclaration 2025), on x86_64-linux.

```sh
nix run github:0x0lor1n/getax-nix
```

GeTax is unfree; the flake sets `allowUnfree` for its own nixpkgs, so no
`--impure` or `NIXPKGS_ALLOW_UNFREE` is needed.

## Where your data goes

GeTax writes declarations, autosaves and logs to `$GETAX_HOME/GeTax2025`,
`$HOME` by default. To keep a year's return and its documents in one folder:

```sh
git clone https://github.com/0x0lor1n/getax-nix && cd getax-nix
echo 'use flake' > .envrc && direnv allow   # or: nix develop
getax-2025                                  # data lands in ./data (git-ignored)
```

## Notes

- Runs the bundled main class with nixpkgs' JDK 17 instead of the shipped
  launcher, which tries to self-update into the read-only store.
- Filing through e-démarches works: the embedded browser gets
  glib-networking for TLS.
- Forced to X11 (`GDK_BACKEND=x11`); SWT under native Wayland is unreliable.
  Override with `GDK_BACKEND=wayland getax-2025`.
- Upstream replaces the tarball at the same URL on each point release, so the
  build breaks with a hash mismatch when a new version ships. Update `hash` and
  `version` in `flake.nix`.
