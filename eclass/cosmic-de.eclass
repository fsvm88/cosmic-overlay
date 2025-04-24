# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the MIT License
# shellcheck shell=bash

# @ECLASS: cosmic-de.eclass
# @MAINTAINER:
# cosmic-de-li7vb3aqt46@fs88.email
# @AUTHOR:
# Fabio Scaccabarozzi
# @BUGREPORTS: Open an Issue at https://github.com/fsvm88/cosmic-overlay/issues
# @VCSURL: https://github.com/fsvm88/cosmic-overlay
# @PROVIDES: cargo git-r3
# @SUPPORTED_EAPIS: 8
# @BLURB: common functions for Cosmic DE packages
# @DESCRIPTION:
# This eclass contains common functions for Cosmic DE packages.

case ${EAPI} in
8) ;;
*) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

### NOTE!
## RUST_MIN_VER and CARGO_OPTIONAL
## MUST come before "inherit cargo"
## otherwise the RUST_DEPEND string is not built

# @ECLASS_VARIABLE: RUST_MIN_VER
# @OUTPUT_VARIABLE
# @DESCRIPTION:
# See description in rust.eclass from main tree.
# This is set to specify the minimum Rust version
RUST_MIN_VER="1.85.1"

# @ECLASS_VARIABLE: CARGO_OPTIONAL
# @INTERNAL
# @DESCRIPTION:
# See description in cargo.eclass from main tree.
# This is set to allow fine-tuning of which functions we use, and when.
CARGO_OPTIONAL=1
inherit cargo

# @ECLASS_VARIABLE: BDEPEND
# @OUTPUT_VARIABLE
# @DESCRIPTION:
# See description of BDEPEND
BDEPEND="
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
>=media-libs/graphene-1.10.8
>=media-libs/gstreamer-1.22.11
>=media-libs/libglvnd-1.7.0
>=media-libs/libpulse-17.0
>=media-video/pipewire-1.0.5
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
"

# @ECLASS_VARIABLE: COSMIC_DE_GVFS_IUSE
# @OUTPUT_VARIABLE
# @DESCRIPTION:
# reusable variable to inject gvfs IUSEs
COSMIC_DE_GVFS_IUSE="afp http nfs samba"
# @ECLASS_VARIABLE: COSMIC_DE_GVFS_DEPENDS
# @OUTPUT_VARIABLE
# @DESCRIPTION:
# reusable variable to inject gvfs DEPENDs
COSMIC_DE_GVFS_DEPENDS="
>=gnome-base/gvfs-1.48.0[afp?,http?,nfs?,samba?]
"

# @ECLASS_VARIABLE: COSMIC_GIT_UNPACK
# @DEFAULT_UNSET
# @DESCRIPTION:
# Allows to use git fetching on non-9999 ebuilds,
# set to anything other than 0 to enable.
if [[ "${PV}" == *9999* ]] ||
	[[ "${COSMIC_GIT_UNPACK}" -ne 0 ]]; then
	# Due to the way things are setup at the moment, we reuse the same DISTDIR repo
	# for multiple versions (e.g.: alpha2 -> alpha3 -> alpha4).
	#
	# Problem is that every time we emerge a new version, the repo with CLONE_TYPE=single
	# does not contain all other refs and is not reset,
	# so the user needs to manually remove it and reclone it.
	#
	# While CLONE_TYPE=mirror increases repo size, for cosmic-edit and cosmic-term
	# this is ~+1MB (~1.5M -> ~2.5M).
	#
	# It's still better for the user to cleanup once/year (or whenever) instead of
	# every time a new version hits the repo. Old/deleted refs are purged in this mode.
	#
	# Related https://github.com/fsvm88/cosmic-overlay/issues/23
	EGIT_CLONE_TYPE=mirror
	EGIT_LFS_CLONE_TYPE=mirror
	inherit git-r3
fi

IUSE+=" debug debug-line-tables-only elogind max-opt systemd"
REQUIRED_USE="
debug? ( !max-opt )
debug-line-tables-only? ( !debug )
max-opt? ( !debug )
^^ ( elogind systemd )
"

# @FUNCTION: cosmic-de_src_unpack
# @DESCRIPTION:
# Unpacks the package and the cargo registry.
# If COSMIC_GIT_UNPACK is enabled, uses git to fetch non-9999 ebuilds.
cosmic-de_src_unpack() {
	if [[ "${PV}" == *9999* ]] || [[ "${COSMIC_GIT_UNPACK}" -ne 0 ]]; then
		git-r3_src_unpack
		if [[ "${COSMIC_GIT_UNPACK}" -ne 0 ]]; then
			PV=9999 cargo_live_src_unpack
		else
			cargo_live_src_unpack
		fi
	else
		cargo_src_unpack
	fi
}

# @FUNCTION: cosmic-de_src_prepare
# @DESCRIPTION:
# Prepares the package and adds the "release-maximum-optimization" profile
cosmic-de_src_prepare() {
	default
	if has max-opt $USE &&
		use max-opt &&
		[ -f Cargo.toml ]; then
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

# @FUNCTION: cosmic-de_src_configure
# @DESCRIPTION:
# Configures the package by selecting the desired profile_name
cosmic-de_src_configure() {
	if [[ "${PV}" == *9999* ]] || [[ "${COSMIC_GIT_UNPACK}" -ne 0 ]]; then
		# These two variables are exported to satisfy vergen's scripts (build.rs).
		# For some projects, some deps are imported via git, however "cargo vendor"
		# seems to strip the ".git" folder, which makes the build scripts fail.
		# Exporting these variables as empty vars is enough to satisfy the scripts.
		# We do not care about these mechanisms anyway in the context of emerge.
		#
		# Example: cosmic-edit depends on cosmic-files via git, which has a build
		# script that tries to configure rebuild information based on
		# GIT_COMMIT_DATE or GIT_SHA.
		#
		# Rather than copy-pasting them when needed in some ebuilds,
		# simply apply them to all projects if we're handling a live ebuild or cloning via git.
		#
		# Previously these were set to empty values, but some components (e.g.: cosmic-edit, cosmic-term)
		# use these to display the build information in the About page.
		VERGEN_GIT_COMMIT_DATE="$(git log -1 --format=%cd)"
		VERGEN_GIT_SHA="$(git rev-parse HEAD)"
		export VERGEN_GIT_COMMIT_DATE VERGEN_GIT_SHA
	fi
	profile_name="release"
	use debug && profile_name="debug"
	use max-opt && profile_name="release-maximum-optimization"
	# The final "${@}" is required to support src_configure overrides (currently cosmic-greeter)
	cargo_src_configure \
		--profile $profile_name \
		$(usev debug-line-tables-only "--config profile.$profile_name.debug=\"line-tables-only\"") \
		"${@}"
}

##### NOTE!
# src_compile and src_test were copy-pasted from cargo.eclass and slightly updated.
#
# cargo.eclass at the moment only supports "debug" or "release" profile, and nothing else.
# This is hardcoded in the conditionals, so while we may pass the entire "profile.release-maximum-optimization"
# via src_configure overrides, it just generates a very long command-line and is less readable.
# Perhaps we can ask upstream to support different profiles at a later time, and remove most of this.

# @FUNCTION: cosmic-de_src_compile
# @DESCRIPTION:
# Compiles the package with the selected profile_name
cosmic-de_src_compile() {
	debug-print-function "${FUNCNAME}" "$@"

	[[ ${_CARGO_GEN_CONFIG_HAS_RUN} ]] ||
		die "FATAL: please call cosmic-de_src_configure before using ${FUNCNAME}"

	filter-lto
	tc-export AR CC CXX PKG_CONFIG

	set -- cargo build "${ECARGO_ARGS[@]}" "$@"
	einfo "${@}"
	"${@}" || die "failed to compile"
}

# @FUNCTION: cosmic-de_src_test
# @DESCRIPTION:
# Tests the package with the selected profile_name
cosmic-de_src_test() {
	debug-print-function "${FUNCNAME}" "$@"

	[[ ${_CARGO_GEN_CONFIG_HAS_RUN} ]] ||
		die "FATAL: please call cosmic-de_src_test before using ${FUNCNAME}"

	set -- cargo test "${ECARGO_ARGS[@]}" "$@"
	einfo "${@}"
	"${@}" || die "cargo test failed"
}

EXPORT_FUNCTIONS src_unpack src_prepare src_configure src_compile src_test

# @FUNCTION: cosmic-de_install_metainfo
# @DESCRIPTION:
# Install a metainfo filter
cosmic-de_install_metainfo() {
	(
		# Wrap the env to avoid messing with insinto
		insinto /usr/share/metainfo
		doins "$1"
	)
}
