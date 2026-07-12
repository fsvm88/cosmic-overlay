# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

RUST_MIN_VER="1.95"

inherit cosmic-live desktop

DESCRIPTION="Simple system info applet for cosmic"
HOMEPAGE="https://github.com/cosmic-utils/cosmic-ext-applet-sysinfo"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH="main"

LICENSE="GPL-3"
LICENSE+="
	0BSD Apache-2.0 BSD BSD-2 BUSL-1.1 CC0-1.0 CDLA-Permissive-2.0 GPL-3 ISC
	MIT MPL-2.0 Unicode-3.0 Unlicense ZLIB
"
SLOT="0"
KEYWORDS="~amd64"

BDEPEND+="
	dev-vcs/git
	dev-util/pkgconf
	virtual/pkgconfig
"

src_install() {
	export APPID="io.github.cosmic_utils.sysinfo-applet"

	exeinto /usr/bin
	doexe "$(cosmic-common_target_dir)/${PN}"

	doicon -s symbolic data/${APPID}-symbolic.svg

	domenu data/${APPID}.desktop

	insinto /usr/share/metainfo
	doins data/${APPID}.metainfo.xml
}
