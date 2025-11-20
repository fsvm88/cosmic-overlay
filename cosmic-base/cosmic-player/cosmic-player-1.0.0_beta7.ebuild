# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de desktop

DESCRIPTION="player for COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-player"

MY_PV="epoch-1.0.0-beta.7"

SRC_URI="
	https://github.com/pop-os/${PN}/archive/refs/tags/${MY_PV}.tar.gz -> ${PN}-${PV}.tar.gz
	https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${P}-crates.tar.zst
	"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

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
