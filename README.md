# cosmic overlay

Overlay for Cosmic desktop environment, developed by System76

## Details

- **this is highly in-flux, no guarantees are given**
- done in a best-effort basis to try out the COSMIC DE, likely not representative of the final product if/when shipped in Gentoo
- it is my first experience writing so many ebuilds and an entire eclass (a lot is taken from gentoo's repo `cargo.eclass`), so expect bugs, and you're welcome to submit PRs for improvements :)
- packages are building according to the submodule commits of the main [pop-os/cosmic-epoch repo](https://github.com/pop-os/cosmic-epoch) - ebuilds DO NOT use `master` branch anymore as of 20.04.2024

## Quick how-to

### Adding the repo and emerging the DE

```shell
eselect repository add cosmic-overlay git https://github.com/fsvm88/cosmic-overlay.git

emerge -1 cosmic-meta pop-theme-meta -pv
```

### Removing the repo

```shell
# -f is required because the repo is not in the official remotes list
eselect repository remove -f cosmic-overlay
```

## USEs

Most ebuilds use the [cosmic-de eclass](eclass/cosmic-de.eclass), part of the repo, and as such expose the following flags:

- `debug`: `cargo build --profile debug`
- `debug-line-tables-only`: adds `--config profile.$profile_name.debug="line-tables-only"` to the build command, to generate debug info that only contains line numbers (useful to get stack traces regardless of build profile)
- `max-opt`: `cargo build --profile release-maximum-optimization`, an injected profile for the ultimate ricing experience!
  - debugging is disabled, unless `debug-line-tables-only` is set
  - 1 codegen unit -> can potentially optimize the code some more (possibly <1%)
  - opt-level=3 -> maximum optimization
  - defined at [eclass/cosmic-de.eclass ~L65](eclass/cosmic-de.eclass#L65)
  - it'll take a while longer to build and link

By default the ebuilds build in `release` mode and profile.

`debug` and `max-opt` are mutually exclusive.

`debug-line-tables-only` can be added on top of the `release`/`max-opt` profiles.

Personally I run with `USE="debug-line-tables-only max-opt"`, and haven't noticed issues.

## Libraries

**NOTE**: these were dropped as of [commit fec5043](https://github.com/fsvm88/cosmic-overlay/commit/fec5043ae4df61d48185b65c6d651a9526b8e0da), as they were unmaintained for a few months.

iced and libcosmic were added, but are not really used by the projects due to Rust's building/linking nature.  
Perhaps at a later time COSMIC devs will add a way to link to system libs, but so far it's clear that doing vendor unbundling is a waste of effort.
