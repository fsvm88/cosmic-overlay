# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

COSMIC_GIT_UNPACK=1

inherit cosmic-de desktop

DESCRIPTION="player for COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-player"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_COMMIT="epoch-1.0.0-alpha.7"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND+="
	>=media-libs/gst-plugins-base-1.22.10
	>=media-libs/gst-plugins-good-1.22.10
"

src_install() {
	dobin "target/$profile_name/$PN"

	domenu res/com.system76.CosmicPlayer.desktop

	cosmic-de_install_metainfo res/com.system76.CosmicPlayer.metainfo.xml

	insinto /usr/share/icons/hicolor
	doins -r res/icons/hicolor/*
}
