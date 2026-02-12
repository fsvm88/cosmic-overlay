# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de-r2 desktop

DESCRIPTION="layer shell notifications daemon for COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-notifications"

SRC_URI="https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${PN}-${PVR}.full.tar.zst"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

BDEPEND+="
	>=dev-util/intltool-0.51.0-r3
"

src_install() {
	dobin "$(cosmic-common_target_dir)/$PN"

	domenu data/com.system76.CosmicNotifications.desktop

	cosmic-de-r2_install_metainfo data/com.system76.CosmicNotifications.metainfo.xml

	insinto /usr/share/icons/hicolor/scalable/apps
	doins data/icons/com.system76.CosmicNotifications.svg
}
