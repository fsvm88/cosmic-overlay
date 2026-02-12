# Copyright 2026 Fabio Scaccabarozzi
# Distributed under the terms of the MIT License
# shellcheck shell=bash

# @ECLASS: cosmic-common.eclass
# @MAINTAINER:
# cosmic-de-li7vb3aqt46@fs88.email
# @AUTHOR:
# Fabio Scaccabarozzi
# @BUGREPORTS: Open an Issue at https://github.com/fsvm88/cosmic-overlay/issues
# @VCSURL: https://github.com/fsvm88/cosmic-overlay
# @PROVIDES: cargo llvm-r1 git-r3 xdg
# @SUPPORTED_EAPIS: 8
# @BLURB: common functions for Cosmic DE packages
# @DESCRIPTION:
# This eclass contains common functions for COSMIC ebuilds (functions, depends, ...).

case ${EAPI} in
8) ;;
*) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

# @ECLASS_VARIABLE: BDEPEND
# @OUTPUT_VARIABLE
# @DESCRIPTION:
# See description of BDEPEND
BDEPEND="
app-arch/zstd
>=virtual/pkgconfig-3
${RUST_DEPEND}
"

# @ECLASS_VARIABLE: RDEPEND
# @OUTPUT_VARIABLE
# @DESCRIPTION:
# Deps are factored out in the eclass, because currently the only way to build
# rust packages is to vendor crates, either "statically" in non-9999 ebuilds,
# or live in 9999 ebuilds.
#
# Being COSMIC an entire DE, pretty much every package depends on libcosmic,
# which depends on iced, the GTK GUI toolkits, dbus, systemd, ....
# Factoring these out ensures that if a user starts from a stage3 install,
# we don't need to specify all deps for all packages, and these (b)deps are
# emerged before we ever try to install the first cosmic-de package.
# If we put them in the -meta package, portage would still potentially merge
# them in parallel.
#
# dbus is an RDEPEND pretty much for the entire DE
# same for systemd
RDEPEND="
>=dev-cpp/glibmm-2.66.7:2
>=dev-libs/glib-2.78.3
>=dev-libs/libinput-1.25.0
>=dev-libs/wayland-1.22
>=gui-libs/gtk-4.12.5
>=media-fonts/open-sans-1-r1
>=media-libs/graphene-1.10.8
>=media-libs/gstreamer-1.22.11
>=media-libs/libglvnd-1.7.0
>=media-libs/libpulse-17.0
>=media-video/pipewire-1.0.5
>=sys-auth/polkit-123-r1
>=virtual/libudev-251-r2
>=x11-libs/cairo-1.18
>=x11-libs/gdk-pixbuf-2.42.10-r1
>=x11-libs/libxkbcommon-1.6.0
>=x11-libs/pango-1.52.1
elogind? ( >=sys-auth/elogind-246.10-r3 )
systemd? ( sys-apps/systemd:= )
|| (
	>=sys-apps/dbus-1.15.8
	>=sys-apps/dbus-broker-36
)
$(llvm_gen_dep '
	llvm-core/clang:${LLVM_SLOT}
	llvm-core/llvm:${LLVM_SLOT}
	'
)
"

IUSE+=" debug debug-line-tables-only elogind max-opt systemd"
REQUIRED_USE="
${LLVM_REQUIRED_USE}
debug? ( !max-opt )
debug-line-tables-only? ( !debug )
max-opt? ( !debug )
^^ ( elogind systemd )
"

cosmic-common_inject_release_max_opt() {
    if has max-opt $USE && use max-opt && [ -f Cargo.toml ]; then
		{
			cat <<'EOF'

[profile.release-maximum-optimization]
inherits = "release"
debug-assertions = false
codegen-units = 1
incremental = false
lto = "thin"
opt-level = 3
overflow-checks = false
panic = "unwind"
EOF
		} >>Cargo.toml
	fi
}

# @FUNCTION: cosmic-common_install_metainfo
# @DESCRIPTION:
# Install a metainfo filter
cosmic-common_install_metainfo() {
	(
		# Wrap the env to avoid messing with insinto
		insinto /usr/share/metainfo
		doins "$1"
	)
}

cosmic-common_target_dir() {
	# For other profiles, profile_name == tdir
	local tdir="${profile_name}"
	# In Cargo, the 'dev' profile (which is the default for `cargo build`) outputs build artifacts to the 'debug' directory.
	# This mapping is non-obvious but is required to match Cargo's convention:
	# https://doc.rust-lang.org/cargo/reference/profiles.html#built-in-profiles
	use debug && tdir="debug"
	echo "target/$tdir"
}
