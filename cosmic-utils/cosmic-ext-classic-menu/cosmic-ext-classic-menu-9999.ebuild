# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

RUST_MIN_VER="1.85.0"
RUST_MAX_VER="1.92.0"
inherit cosmic-de desktop

DESCRIPTION="Classic style customizable application launcher for COSMIC DE"
HOMEPAGE="https://github.com/championpeak87/cosmic-ext-classic-menu"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH="master"

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
	doexe "$(cosmic-de_target_dir)/cosmic-ext-classic-menu-applet"
	doexe "$(cosmic-de_target_dir)/cosmic-ext-classic-menu-settings"

	export APPID="com.championpeak87.cosmic-ext-classic-menu"

	domenu res/${APPID}.desktop

	cosmic-de_install_metainfo res/${APPID}.metainfo.xml

	doicon -s scalable res/icons/hicolor/scalable/apps/${APPID}.svg

	insinto /usr/share/cosmic/${APPID}/applet-buttons
	doins -r res/icons/bundled/applet-button/*.svg
}
