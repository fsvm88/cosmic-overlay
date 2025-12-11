# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake git-r3

DESCRIPTION="Qt platform theme for the COSMIC Desktop environment"
HOMEPAGE="https://github.com/IgKh/cutecosmic"
EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH="master"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS=""
RESTRICT="network-sandbox"

PATCHES=(
	"${FILESDIR}/${PN}-0.1-system-corrosion.patch"
)

DEPEND="
	>=dev-qt/qtbase-6.8.0:6=[dbus,gui]
	>=dev-qt/qtdeclarative-6.8.0:6=
"
RDEPEND="${DEPEND}"
BDEPEND="
	>=dev-build/cmake-3.22
	>=dev-build/corrosion-0.6.0
	>=dev-lang/rust-1.85.1
	dev-qt/qtbase:6[gui]
	virtual/rust
"

src_configure() {
	local mycmakeargs=(
		-DCMAKE_BUILD_TYPE=Release
	)
	cmake_src_configure
}

src_install() {
	cmake_src_install
}
