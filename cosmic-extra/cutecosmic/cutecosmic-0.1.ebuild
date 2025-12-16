# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

RUST_MAX_VER="1.92.0"
inherit cmake

DESCRIPTION="Qt platform theme for the COSMIC Desktop environment"
HOMEPAGE="https://github.com/IgKh/cutecosmic"
SRC_URI="https://github.com/IgKh/cutecosmic/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"
RESTRICT="network-sandbox"

PATCHES=(
	"${FILESDIR}/${P}-system-corrosion.patch"
)

RDEPEND="
    >=dev-qt/qtbase-6.8.0:6=[dbus,gui]
    >=dev-qt/qtdeclarative-6.8.0:6=
"
BDEPEND="
    >=dev-build/cmake-3.22
    >=dev-build/corrosion-0.6.0
    >=dev-qt/qtbase-6.8.0:6=[dbus,gui]
    >=dev-qt/qtdeclarative-6.8.0:6=
    dev-lang/rust
"
