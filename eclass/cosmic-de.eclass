# shellcheck shell=bash
# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the MIT License

# @ECLASS: cosmic-de.eclass
# @MAINTAINER:
# cosmic-de-li7vb3aqt46@fs88.email
# @AUTHOR:
# Fabio Scaccabarozzi
# @SUPPORTED_EAPIS: 8
# @BLURB: common functions for Cosmic DE packages

case ${EAPI} in
	8) ;;
	*) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

# Deps are factored out in the eclass, because rust links everything statically,
# and pretty much every package in Cosmic depends on libcosmic, which depends
# on iced, the GTK GUI toolkits, dbus, systemd, ....
# Factoring these out ensures that if a user starts from a stage3 install,
# we don't need to specify all deps for all packages, and these (b)deps are
# emerged before we ever try to install the first cosmic-de package.
# If we put them in the -meta package, portage would still potentially merge
# them in parallel.
DEPEND="
>=dev-cpp/glibmm-2.66.7:2
>=dev-libs/glib-2.78.3
>=dev-libs/libinput-1.25.0
>=dev-libs/wayland-1.22
>=gui-libs/gtk-4.12.5
>=media-libs/graphene-1.10.8
>=media-libs/gstreamer-1.22.11
>=media-libs/libglvnd-1.7.0
>=media-libs/libpulse-17.0
>=virtual/libudev-251-r2
>=x11-libs/cairo-1.18:1.16
>=x11-libs/gdk-pixbuf-2.42.10-r1
>=x11-libs/libxkbcommon-1.6.0
>=x11-libs/pango-1.52.1
"
BDEPEND="
>=virtual/pkgconfig-3
>=virtual/rust-1.75.0
"
# dbus is an RDEPEND pretty much for the entire DE
# same for systemd
RDEPEND="
elogind? ( >=sys-auth/elogind-246.10-r3 )
systemd? ( >=sys-apps/systemd-255.3-r1 )
>=sys-apps/dbus-1.15.8
"

CARGO_OPTIONAL=1
inherit cargo

[[ "${PV}" == *9999* ]] && inherit git-r3

IUSE="${IUSE} debug debug-line-tables-only elogind max-opt systemd"
REQUIRED_USE="
debug? ( !max-opt )
debug-line-tables-only? ( !debug )
max-opt? ( !debug )
^^ ( elogind systemd )
"

# @FUNCTION: cosmic-de_src_unpack
# @DESCRIPTION:
# Unpacks the package and the cargo registry.
cosmic-de_src_unpack() {
	if [[ "${PV}" == *9999* ]]; then
		git-r3_src_unpack
		cargo_live_src_unpack
	else
		cargo_src_unpack
	fi
}

# @FUNCTION: cosmic-de_src_prepare
# @DESCRIPTION:
# Prepares the package and adds the "release-maximum-optimization" profile
cosmic-de_src_prepare() {
	default
	if has max-opt $USE \
		&& use max-opt \
		&& [ -f Cargo.toml ] ; then
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
		} >> Cargo.toml
	fi

	if [ -f justfile ]; then
		# Allow configurable profile name for output folder for _install_bin (debug, release-maximum-optimization)
		# This will need to be passed later
		sed -i 's,^bin-src.*,bin-src \:= "target" / profile_name / name,' justfile
		# This is required to allow the change above to take place
		if ! grep -q '^target' justfile; then
			sed -i '1i profile_name := "release"' justfile
		fi
	fi
}

# @FUNCTION: cosmic-de_src_configure
# @DESCRIPTION:
# Configures the package by selecting the desired profile_name
cosmic-de_src_configure() {
	profile_name="release"
	use debug && profile_name="debug"
	use max-opt && profile_name="release-maximum-optimization"
	# The final "${@}" is required to support src_configure overrides (currently cosmic-greeter)
	cargo_src_configure \
		--profile $profile_name \
		$(usev debug-line-tables-only "--config profile.$profile_name.debug=\"line-tables-only\"") \
		"${@}"
}

# @FUNCTION: cosmic-de_src_compile
# @DESCRIPTION:
# Compiles the package with the selected profile_name
cosmic-de_src_compile() {
	debug-print-function "${FUNCNAME}" "$@"

	[[ ${_CARGO_GEN_CONFIG_HAS_RUN} ]] || \
		die "FATAL: please call cargo_gen_config before using ${FUNCNAME}"
	
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

	[[ ${_CARGO_GEN_CONFIG_HAS_RUN} ]] || \
		die "FATAL: please call cargo_gen_config before using ${FUNCNAME}"

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
