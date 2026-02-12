# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de-r2 desktop

DESCRIPTION="launcher for COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-launcher"


SRC_URI="https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${PN}-${PVR}.full.tar.zst"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

BDEPEND+="
	>=dev-util/intltool-0.51.0-r3
"
RDEPEND+="
	~cosmic-base/pop-launcher-9999
"

src_install() {
	dobin "$(cosmic-de-r2_target_dir)/$PN"

	domenu data/com.system76.CosmicLauncher.desktop

	cosmic-de-r2_install_metainfo data/com.system76.CosmicLauncher.metainfo.xml

	insinto /usr/share/icons/hicolor/scalable/apps
	doins data/icons/com.system76.CosmicLauncher.svg
}
