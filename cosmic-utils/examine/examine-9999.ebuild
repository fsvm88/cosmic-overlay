# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

RUST_MIN_VER="1.85.0"
RUST_MAX_VER="1.92.0"
inherit cosmic-de desktop

DESCRIPTION="A system information viewer for the COSMIC DE"
HOMEPAGE="https://github.com/cosmic-utils/examine"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH="main"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

BDEPEND+="
	dev-vcs/git
	dev-util/pkgconf
	virtual/pkgconfig
"

src_install() {
	exeinto /usr/bin
	doexe "$(cosmic-de_target_dir)/${PN}"

	export APPID="io.github.cosmic_utils.Examine"

	doicon -s scalable res/icons/hicolor/scalable/apps/${APPID}.svg

	domenu res/${APPID}.desktop

	cosmic-de_install_metainfo res/${APPID}.metainfo.xml
}
