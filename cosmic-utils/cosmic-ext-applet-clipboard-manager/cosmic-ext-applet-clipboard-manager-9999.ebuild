# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cosmic-live desktop

DESCRIPTION="Clipboard manager for COSMIC"
HOMEPAGE="https://github.com/cosmic-utils/clipboard-manager"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH="master"

LICENSE="GPL-3"
LICENSE+="
	Apache-2.0 BSD BSD-2 CC0-1.0 GPL-3 ISC LGPL-3+ MIT MPL-2.0 Unicode-3.0
	Unlicense ZLIB
"
SLOT="0"
KEYWORDS="~amd64"

BDEPEND+="
	dev-vcs/git
	dev-util/pkgconf
	virtual/pkgconfig
"

src_install() {
	export APPID="io.github.cosmic_utils.cosmic-ext-applet-clipboard-manager"

	exeinto /usr/bin
	doexe "$(cosmic-common_target_dir)/${PN}"

	newicon -s scalable res/app_icon.svg ${APPID}-symbolic.svg

	newmenu res/desktop_entry.desktop ${APPID}.desktop

	insinto /usr/share/metainfo
	newins res/metainfo.xml ${APPID}.metainfo.xml
}
