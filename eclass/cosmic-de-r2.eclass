# Copyright 2026 Fabio Scaccabarozzi
# Distributed under the terms of the MIT License
# shellcheck shell=bash

# @ECLASS: cosmic-de-r2.eclass
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
RUST_MIN_VER="1.90.0"

# @ECLASS_VARIABLE: LLVM_COMPAT
# @DESCRIPTION:
# See description in llvm-r1.eclass from main tree.
# This is set to specify which LLVM versions we support.
LLVM_COMPAT=({20..22})
# @ECLASS_VARIABLE: LLVM_OPTIONAL
# @DESCRIPTION:
# See description in llvm-r1.eclass from main tree.
# This is set to allow fine-tuning of which functions we use, and when.
LLVM_OPTIONAL=1
inherit llvm-r1

# @ECLASS_VARIABLE: CARGO_OPTIONAL
# @INTERNAL
# @DESCRIPTION:
# See description in cargo.eclass from main tree.
# This is set to allow fine-tuning of which functions we use, and when.
CARGO_OPTIONAL=1
inherit cargo xdg

# Brings in dependencies and a couple utility functions
inherit cosmic-common

# @FUNCTION: cosmic-de-r2_pkg_setup
# @DESCRIPTION:
# Sets up rust and LLVM environment.
# libcosmic and possibly other packages depend on clang being available
# due to libclang dependency
cosmic-de-r2_pkg_setup() {
	rust_pkg_setup
	llvm-r1_pkg_setup
}

# @FUNCTION: cosmic-de-r2_src_unpack
# @DESCRIPTION:
# Unpacks the package and the cargo registry.
# If COSMIC_GIT_UNPACK is enabled, uses git to fetch non-9999 ebuilds.
cosmic-de-r2_src_unpack() {
	debug-print-function ${FUNCNAME} "$@"

	pushd "${DISTDIR}" >/dev/null || die
	mkdir -p "${S}" || die

	for archive in ${A}; do
		case "${archive}" in
		*.full.tar.zst)
			tar -x -I 'zstd --long=31' -C "${S}" -f "${archive}" --strip-components=1
			;;
		*)
			tar -x -C "${S}" -f "${archive}" --strip-components=1
			;;
		esac
	done
	popd >/dev/null || die

	cargo_gen_config
}

# @FUNCTION: cosmic-de-r2_src_prepare
# @DESCRIPTION:
# Prepares the package and adds the "release-maximum-optimization" profile
cosmic-de-r2_src_prepare() {
	default
	cosmic-common_inject_release_max_opt
}

# @FUNCTION: cosmic-de-r2_src_configure
# @DESCRIPTION:
# Configures the package by selecting the desired profile_name
cosmic-de-r2_src_configure() {
	profile_name="release"
	use debug && profile_name="dev"
	use max-opt && profile_name="release-maximum-optimization"
	# The final "${@}" is required to support src_configure overrides (currently cosmic-greeter)
	cargo_src_configure --frozen \
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

# @FUNCTION: cosmic-de-r2_src_compile
# @DESCRIPTION:
# Compiles the package with the selected profile_name
cosmic-de-r2_src_compile() {
	debug-print-function "${FUNCNAME}" "$@"

	[[ ${_CARGO_GEN_CONFIG_HAS_RUN} ]] ||
		die "FATAL: please call cosmic-de-r2_src_configure before using ${FUNCNAME}"

	filter-lto
	tc-export AR CC CXX PKG_CONFIG

	set -- cargo build "${ECARGO_ARGS[@]}" "$@"
	einfo "${@}"
	"${@}" || die "failed to compile"
}

# @FUNCTION: cosmic-de-r2_src_test
# @DESCRIPTION:
# Tests the package with the selected profile_name
cosmic-de-r2_src_test() {
	debug-print-function "${FUNCNAME}" "$@"

	[[ ${_CARGO_GEN_CONFIG_HAS_RUN} ]] ||
		die "FATAL: please call cosmic-de-r2_src_test before using ${FUNCNAME}"

	set -- cargo test "${ECARGO_ARGS[@]}" "$@"
	einfo "${@}"
	"${@}" || die "cargo test failed"
}

# @FUNCTION: cosmic-de-r2_pkg_preinst
# @DESCRIPTION:
# See xdg eclass
cosmic-de-r2_pkg_preinst() {
	xdg_pkg_preinst
}

# @FUNCTION: cosmic-de-r2_pkg_postinst
# @DESCRIPTION:
# See xdg eclass
cosmic-de-r2_pkg_postinst() {
	xdg_pkg_postinst
}

# @FUNCTION: cosmic-de-r2_pkg_postrm
# @DESCRIPTION:
# See xdg eclass
cosmic-de-r2_pkg_postrm() {
	xdg_pkg_postrm
}

EXPORT_FUNCTIONS pkg_setup src_unpack src_prepare src_configure src_compile src_test pkg_preinst pkg_postinst pkg_postrm
