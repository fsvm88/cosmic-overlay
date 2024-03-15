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

# Not every package needs these, but 9 out of 10 do. Just factor these out.
DEPEND="
dev-libs/wayland
x11-libs/libxkbcommon
"
BDEPEND="
>=virtual/rust-1.75.0
virtual/pkgconfig
"

CARGO_OPTIONAL=1
inherit cargo

[[ "${PV}" == *9999* ]] && inherit git-r3

IUSE="${IUSE} debug max-opt"
REQUIRED_USE="
debug? ( !max-opt )
max-opt? ( !debug )
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
debug = "line-tables-only"
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
	cargo_src_configure "$@"
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

	set -- cargo build --profile "${profile_name}" "${ECARGO_ARGS[@]}" "$@"
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

	set -- cargo test --profile "${profile_name}" "${ECARGO_ARGS[@]}" "$@"
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
