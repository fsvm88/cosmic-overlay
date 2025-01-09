# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de

DESCRIPTION="player for COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-player"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH=master

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS=""

src_install() {
	dobin "target/$profile_name/$PN"

	domenu res/com.system76.CosmicPlayer.desktop

	cosmic-de_install_metainfo res/com.system76.CosmicPlayer.metainfo.xml

	insinto /usr/share/icons/hicolor
	doins -r res/icons/hicolor/*
}
