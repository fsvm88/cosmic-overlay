# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de desktop

DESCRIPTION="player for COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-player"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH=master

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS=""

RDEPEND+="
	>=media-libs/gst-plugins-base-1.22.10
	>=media-libs/gst-plugins-good-1.22.10
"

src_install() {
	dobin "$(cosmic-de_target_dir)/$PN"

	domenu res/com.system76.CosmicPlayer.desktop

	cosmic-de_install_metainfo res/com.system76.CosmicPlayer.metainfo.xml

	insinto /usr/share/icons/hicolor
	doins -r res/icons/hicolor/*

	insinto /usr/share/thumbnailers
	doins res/com.system76.CosmicPlayer.thumbnailer
}
