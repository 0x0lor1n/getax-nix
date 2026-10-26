# getax-nix

Nix flake for [GeTax PP](https://www.getax.ch/support/telecharger), the
Geneva personal tax return software, on x86_64-linux.

```sh
nix run github:0x0lor1n/getax-nix               # latest tax year
nix run github:0x0lor1n/getax-nix#getax-2025    # a specific year
```

GeTax is unfree; the flake sets `allowUnfree` for its own nixpkgs, so no
`--impure` or `NIXPKGS_ALLOW_UNFREE` is needed.

## Where your data goes

GeTax writes declarations, autosaves and logs to `$GETAX_HOME/GeTax<year>`,
`$HOME` by default. To keep returns and their documents in one folder:

```sh
git clone https://github.com/0x0lor1n/getax-nix && cd getax-nix
direnv allow                                # or: nix develop
getax-2025                                  # data lands in ./data (git-ignored)
```

### Ephemeral home (impermanence)

With the default `GETAX_HOME=$HOME` a wiped home takes the declaration with
it. Either set `GETAX_HOME` to persisted storage (e.g.
`home.sessionVariables.GETAX_HOME = "/persist/tax";`), or persist what GeTax
writes under it:

```nix
environment.persistence."/persist".users.<name>.directories = [
  "GeTax2025"   # declarations, autosaves, filed-copy PDFs (pp/depot); one dir per year
  "dvbern-tax"  # table layout settings
];
```

`.swt` (unpacked native libs) is a cache and can stay ephemeral.

## Updates

Each tax year is a separate GeTax release; `releases.json` pins one tarball
per year. Upstream replaces a year's tarball at the same URL on each point
release, which breaks the build with a hash mismatch until re-pinned.

```sh
nix run .#update          # re-pin changed years, add the next year if published
nix run .#update -- 2024  # pin a given year
```

`.github/workflows/update.yml` runs this weekly, builds every year and opens a
PR when `releases.json` changes. Enable "Allow GitHub Actions to create pull
requests" in the repo settings for it to work.

## Notes

- Runs the bundled main class with nixpkgs' JDK 17 instead of the shipped
  launcher, which tries to self-update into the read-only store.
- Filing through e-démarches works: the embedded browser gets
  glib-networking for TLS.
- Forced to X11 (`GDK_BACKEND=x11`); SWT under native Wayland is unreliable.
  Override with `GDK_BACKEND=wayland getax-2025`.
