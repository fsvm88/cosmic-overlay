# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de desktop

DESCRIPTION="display background service for COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-bg"

MY_PV="epoch-1.0.5"

SRC_URI="
	https://github.com/pop-os/${PN}/archive/refs/tags/${MY_PV}.tar.gz -> ${PN}-${PV}.tar.gz
	https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${P}-crates.tar.zst
	"

# use cargo-license for a more accurate license picture
LICENSE="MPL-2.0"
SLOT="0"
KEYWORDS="~amd64"

src_install() {
	dobin "$(cosmic-de_target_dir)/$PN"

	domenu data/com.system76.CosmicBackground.desktop

	cosmic-de_install_metainfo data/com.system76.CosmicBackground.metainfo.xml

	insinto /usr/share/cosmic/com.system76.CosmicBackground/v1
	doins data/v1/*

	insinto /usr/share/icons/hicolor/symbolic/apps/
	doins data/icons/com.system76.CosmicBackground-symbolic.svg

	insinto /usr/share/icons/hicolor/scalable/apps/
	doins data/icons/com.system76.CosmicBackground.svg
}
