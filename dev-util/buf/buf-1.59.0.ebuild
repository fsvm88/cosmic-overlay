# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit go-module

DESCRIPTION="A new way of working with Protocol Buffers"
HOMEPAGE="https://buf.build https://github.com/bufbuild/buf"
SRC_URI="https://github.com/bufbuild/buf/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

S="${WORKDIR}/${P}"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

# Go modules are vendored or fetched during build
# Tests fail
RESTRICT="network-sandbox test"

BDEPEND=">=dev-lang/go-1.20"

src_unpack() {
	default
	cd "${S}" || die

	# Fetch Go dependencies
	einfo "Fetching Go dependencies..."
	go mod download -x || die "Failed to download Go modules"
}

src_compile() {
	einfo "Building buf CLI tool..."
	go build -o buf ./cmd/buf || die "Failed to build buf"
}

src_install() {
	dobin buf

	# Install documentation
	dodoc README.md
	if [[ -f LICENSE ]]; then
		dodoc LICENSE
	fi
}

pkg_postinst() {
	elog "buf is a tool for working with Protocol Buffers."
	elog "For more information, visit: https://buf.build"
}
