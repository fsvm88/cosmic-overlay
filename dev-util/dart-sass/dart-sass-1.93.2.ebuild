# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="The reference implementation of Sass, written in Dart (built from source)"
HOMEPAGE="https://sass-lang.com/dart-sass https://github.com/sass/dart-sass"

BUF_VERSION="v1.57.2"
SRC_URI="
	https://github.com/sass/dart-sass/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz
	https://github.com/bufbuild/buf/archive/refs/tags/${BUF_VERSION}.tar.gz -> buf-${BUF_VERSION}.tar.gz
"

S="${WORKDIR}/${P}"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

IUSE="doc"
# network-sandbox: extra stuff to build
# strip: the executable built is standalone,
#			so it contains a copy of the runtime, which means the debug ID and folder is the same
RESTRICT="network-sandbox strip"

# dart-sass is the successor to dev-ruby/sass
# has been deprecated and unsupported for a few years upstream now
# the user, adw-gtk3, has migrated to dart-sass since >=6.0
# the two have incompatible CLI options
RDEPEND="
	!dev-ruby/sass
	!dev-util/dart-sass-bin
"

BDEPEND="
	>=dev-lang/dart-3.0.0
	>=dev-lang/go-1.20
	dev-vcs/git
"

src_unpack() {
	default
	cd "${S}"

	einfo "Fetching Dart dependencies..."
	dart pub get

	einfo "Fetching sass specification for protocol buffers..."
	git clone --depth 1 https://github.com/sass/sass.git "${WORKDIR}/sass-spec" || die "Failed to clone sass specification"
}

src_compile() {
	einfo "Building buf CLI tool..."
	pushd "${WORKDIR}/buf-${BUF_VERSION#v}" || die "Failed to enter buf directory"
	go build -o "${S}/buf" ./cmd/buf || die "Failed to build buf"
	popd || die "Failed to return to main directory"

	einfo "Building protocol buffers..."
	# Set the sass specification path and use the grinder task 
	# which knows how to handle the protocol buffer generation
	export SASS_SPEC_PATH="${WORKDIR}/sass-spec"
	PATH="${S}:${PATH}" dart run grinder protobuf || die "Failed to build protocol buffers"

	einfo "Compiling dart-sass to native executable..."
	dart compile exe bin/sass.dart -o sass || die "Failed to compile dart-sass"
}

src_test() {
	export SASS_SPEC_PATH="${WORKDIR}/sass-spec"

	einfo "Preparing test requirements..."
	dart run grinder pkg-standalone-dev || die "Failed to prepare pkg-standalone-dev"
	dart run grinder pkg-npm-dev || die "Failed to prepare pkg-npm-dev"

	einfo "Running dart-sass tests..."
	dart run test -x node || die "Tests failed"
}

src_install() {
	# Install the compiled binary
	dobin sass

	# Install documentation
	if use doc; then
		local doc_files=( README.md LICENSE CHANGELOG.md )
		for doc_file in "${doc_files[@]}"; do
			if [[ -f "${doc_file}" ]]; then
				dodoc "${doc_file}"
			fi
		done
	fi
}

pkg_postinst() {
	elog "Dart Sass has been installed and is available as 'sass'."
	elog ""
	elog "This is the reference implementation of Sass, built from source using Dart."
	elog "It replaces the deprecated Ruby implementation (dev-ruby/sass)."
	elog ""
	elog "For more information, visit: https://sass-lang.com/"
}
