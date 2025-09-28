# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{10..13} )

inherit check-reqs multiprocessing python-any-r1

DESCRIPTION="Google's Dart programming language SDK"
HOMEPAGE="https://dart.dev https://github.com/dart-lang/sdk"

# No source URI as we use depot_tools to fetch source
SRC_URI=""

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

IUSE="debug doc test"

RESTRICT="network-sandbox test"  # Requires network access during unpack/compile

# Build dependencies
BDEPEND="
	${PYTHON_DEPS}
	dev-vcs/git
	net-misc/curl
	app-arch/xz-utils
"

# Runtime dependencies
RDEPEND=""
DEPEND="${RDEPEND}"

S="${WORKDIR}/dart-sdk"

dart_check_reqs() {
	local CHECKREQS_DISK_BUILD=15G
	local CHECKREQS_DISK_USR=600M
	local CHECKREQS_MEMORY=16G
	check-reqs_${EBUILD_PHASE_FUNC}
}

pkg_pretend() {
	dart_check_reqs
}

pkg_setup() {
	dart_check_reqs
	python-any-r1_pkg_setup
}

src_unpack() {
	# Create work directory structure
	mkdir -p "${S}" || die "Failed to create work directory"
	cd "${S}" || die "Failed to cd to work directory"

	# Clone depot_tools
	einfo "Cloning depot_tools..."
	git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git \
		|| die "Failed to clone depot_tools"

	# Add depot_tools to PATH
	export PATH="${S}/depot_tools:${PATH}"

	# Fetch Dart SDK source using gclient
	einfo "Fetching Dart SDK source (this may take a while)..."
	fetch dart || die "Failed to fetch Dart SDK source"

	# Switch to the specific version tag
	cd sdk || die "Failed to cd to sdk directory"
	git fetch --tags || die "Failed to fetch tags"
	git checkout "${PV}" || die "Failed to checkout version ${PV}"

	# Sync dependencies
	einfo "Syncing dependencies..."
	gclient sync || die "Failed to sync dependencies"
}

src_compile() {
	# Set up depot_tools PATH
	export PATH="${S}/depot_tools:${PATH}"
	cd "${S}/sdk" || die "Failed to pushd to sdk directory"

	local build_mode="release"
	use debug && build_mode="debug"

	local build_args=()
	build_args+=( "--mode" "${build_mode}" )

	# Architecture detection
	local arch
	case ${ARCH} in
		amd64) arch="x64" ;;
		arm64) arch="arm64" ;;
		*) die "Unsupported architecture: ${ARCH}" ;;
	esac
	build_args+=( "--arch" "${arch}" )

	# Build targets
	local targets=( "create_sdk" )
	use test && targets+=( "run_ffi_unit_tests" )

	einfo "Building Dart SDK with: ${build_args[*]} ${targets[*]}"
	./tools/build.py -j$(get_makeopts_jobs) "${build_args[@]}" "${targets[@]}" \
		|| die "Failed to build Dart SDK"
}

src_test() {
	# Set up depot_tools PATH
	export PATH="${S}/depot_tools:${PATH}"
	cd "${S}/sdk" || die "Failed to pushd to sdk directory"

	local build_mode="release"
	use debug && build_mode="debug"

	einfo "Running Dart SDK tests..."
	./tools/test.py --mode="${build_mode}" --runtime=vm corelib \
		|| die "Tests failed"
}

src_install() {
	local build_mode="release"
	use debug && build_mode="debug"

	local arch
	case ${ARCH} in
		amd64) arch="X64" ;;
		arm64) arch="ARM64" ;;
		*) die "Unsupported architecture: ${ARCH}" ;;
	esac

	local out_dir="sdk/out/${build_mode^}${arch}/dart-sdk"

	# Install the entire SDK
	local install_dir="/usr/$(get_libdir)/dart"
	insinto "${install_dir}"
	doins -r "${out_dir}"/*

	for onebin in dart dartaotruntime utils/gen_snapshot utils/wasm-opt; do
		fperms a+x "${install_dir}/bin/$onebin"
	done

	dodoc "${out_dir}"/README
	dodoc "${out_dir}"/LICENSE

	# Set up environment
	dodir /etc/env.d
	cat > "${ED}/etc/env.d/50dart" <<-EOF || die
		DART_SDK="${install_dir}"
		PATH="${install_dir}/bin"
	EOF
}

pkg_postinst() {
	elog "Dart SDK has been installed to /usr/$(get_libdir)/dart"
	elog ""
	elog "The 'dart' command is available in your PATH."
	elog ""
	elog "You may want to run 'env-update && source /etc/profile' to update your environment."
	elog ""
	elog "For more information on using Dart, visit: https://dart.dev"
}
