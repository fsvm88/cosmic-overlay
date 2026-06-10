# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de-r2 desktop

DESCRIPTION="player for COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-player"

SRC_URI="https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${PN}-${PVR}.full.tar.zst"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND+="
	>=media-libs/gst-plugins-base-1.22.10
	>=media-libs/gst-plugins-good-1.22.10
"

src_install() {
	dobin "$(cosmic-common_target_dir)/$PN"

	domenu res/com.system76.CosmicPlayer.desktop

	cosmic-common_install_metainfo res/com.system76.CosmicPlayer.metainfo.xml

	insinto /usr/share/icons/hicolor
	doins -r res/icons/hicolor/*

	insinto /usr/share/thumbnailers
	doins res/com.system76.CosmicPlayer.thumbnailer
}
