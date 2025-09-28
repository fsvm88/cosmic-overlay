# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{10..13} )

inherit python-any-r1

DESCRIPTION="Google's Dart programming language SDK"
HOMEPAGE="https://dart.dev https://github.com/dart-lang/sdk"

# No source URI as we use depot_tools to fetch source
SRC_URI=""

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

IUSE="analyzer debug doc test"

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

pkg_setup() {
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

	# Move sdk contents to expected location
	cd .. || die
	if [[ -d sdk ]]; then
		mv sdk/* . || die "Failed to move SDK contents"
		rmdir sdk || die "Failed to remove empty sdk directory"
	fi
}

src_compile() {
	# Set up depot_tools PATH
	export PATH="${S}/depot_tools:${PATH}"

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
	./tools/build.py "${build_args[@]}" "${targets[@]}" \
		|| die "Failed to build Dart SDK"
}

src_test() {
	if use test; then
		# Set up depot_tools PATH
		export PATH="${S}/depot_tools:${PATH}"

		local build_mode="release"
		use debug && build_mode="debug"

		einfo "Running Dart SDK tests..."
		./tools/test.py --mode="${build_mode}" --runtime=vm corelib \
			|| die "Tests failed"
	fi
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

	local sdk_dir="out/${build_mode^}${arch}/dart-sdk"

	if [[ ! -d "${sdk_dir}" ]]; then
		die "Built SDK not found at ${sdk_dir}"
	fi

	# Install the entire SDK to /usr/lib64/dart-sdk
	local install_dir="/usr/lib64/dart-sdk"
	insinto "${install_dir}"
	doins -r "${sdk_dir}"/*

	# Make binaries executable
	local bin_dir="${ED}${install_dir}/bin"
	if [[ -d "${bin_dir}" ]]; then
		fperms +x "${install_dir}"/bin/*
	fi

	# Create symlinks in /usr/bin for main executables
	local binaries=( dart )
	use analyzer && binaries+=( dartanalyzer )

	for binary in "${binaries[@]}"; do
		if [[ -f "${bin_dir}/${binary}" ]]; then
			dosym "../../lib64/dart-sdk/bin/${binary}" "/usr/bin/${binary}"
		fi
	done

	# Install documentation if requested
	if use doc; then
		local doc_files=( README.md LICENSE CHANGELOG.md )
		for doc_file in "${doc_files[@]}"; do
			if [[ -f "${sdk_dir}/${doc_file}" ]]; then
				dodoc "${sdk_dir}/${doc_file}"
			fi
		done
	fi

	# Set up environment
	dodir /etc/env.d
	cat > "${ED}/etc/env.d/50dart" <<-EOF || die
		DART_SDK="${install_dir}"
		PATH="${install_dir}/bin"
	EOF
}

pkg_postinst() {
	elog "Dart SDK has been installed to /usr/lib64/dart-sdk"
	elog ""
	elog "The 'dart' command is available in your PATH."
	if use analyzer; then
		elog "The 'dartanalyzer' command is also available."
	fi
	elog ""
	elog "You may want to run 'env-update && source /etc/profile' to update your environment."
	elog ""
	elog "For more information on using Dart, visit: https://dart.dev"
}