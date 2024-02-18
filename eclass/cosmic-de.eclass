# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

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

BDEPEND="
>=virtual/rust-1.75.0
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
}

# @FUNCTION: cosmic-de_src_configure
# @DESCRIPTION:
# Configures the package by selecting the desired profile_name
cosmic-de_src_configure() {
	profile_name="release"
	use debug && profile_name="debug"
	use max-opt && profile_name="release-maximum-optimization"
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

# @FUNCTION: cosmic-de_src_install
# @DESCRIPTION:
# Installs the package with the selected profile_name
cosmic-de_src_install() {
	debug-print-function "${FUNCNAME}" "$@"

	[[ ${_CARGO_GEN_CONFIG_HAS_RUN} ]] || \
		die "FATAL: please call cargo_gen_config before using ${FUNCNAME}"

	if [ -f justfile ]; then
		set -- just --set rootdir "${D}" --set target "${profile_name}" install
		einfo "${@}"
		"${@}" || die "failed installing via just"
	fi

	rm -f "${ED}/usr/.crates.toml" || die
    rm -f "${ED}/usr/.crates2.json" || die
}


EXPORT_FUNCTIONS src_unpack src_prepare src_configure src_compile src_install src_test
