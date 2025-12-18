# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

RUST_MIN_VER="1.85.0"
RUST_MAX_VER="1.92.0"
inherit cosmic-de desktop

DESCRIPTION="GameMode Status COSMIC DE Applet"
HOMEPAGE="https://github.com/D-Brox/cosmic-ext-applet-gamemode-status"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH="main"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND+="
	>=games-util/gamemode-1.8.1
"

BDEPEND+="
	dev-vcs/git
	dev-util/pkgconf
	virtual/pkgconfig
"

src_install() {
	exeinto /usr/bin
	doexe "$(cosmic-de_target_dir)/${PN}"

#	insinto /usr/share/icons/hicolor/scalable/apps
#	doicon -s scalable res/net.tropicbliss.CosmicExtAppletCaffeine-empty.svg
#	doicon -s scalable res/net.tropicbliss.CosmicExtAppletCaffeine-full.svg

	domenu res/dev.DBrox.CosmicGameModeStatus.desktop

	insinto /usr/share/metainfo
	doins res/dev.DBrox.CosmicGameModeStatus.metainfo.xml
}
