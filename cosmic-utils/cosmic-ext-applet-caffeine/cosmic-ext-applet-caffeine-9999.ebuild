# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cosmic-de desktop

DESCRIPTION="Caffeine Applet for the COSMIC DE"
HOMEPAGE="https://github.com/tropicbliss/cosmic-ext-applet-caffeine"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH="main"

# use cargo-license for a more accurate license picture
LICENSE="GPL-2+"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND+="
	>=dev-libs/expat-2.5.0
	>=media-libs/fontconfig-2.14.2-r3
	>=media-libs/freetype-2.13.2
	>=x11-libs/libXft-2.3.9
"

BDEPEND+="
	dev-vcs/git
	virtual/pkgconfig
"

src_prepare() {
	cosmic-de_src_prepare

	# Fix wrong desktop file categories
	sed -i 's/Categories=.*/Categories=COSMIC;/' res/net.tropicbliss.CosmicExtAppletCaffeine.desktop
}

src_install() {
	export APPID="net.tropicbliss.CosmicExtAppletCaffeine"

	exeinto /usr/bin
	doexe "$(cosmic-de_target_dir)/${PN}"

	doicon -s scalable res/${APPID}-empty.svg
	doicon -s scalable res/${APPID}-full.svg

	domenu res/${APPID}.desktop

	cosmic-de_install_metainfo res/${APPID}.metainfo.xml
}
