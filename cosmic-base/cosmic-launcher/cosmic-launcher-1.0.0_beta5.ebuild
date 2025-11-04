# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de desktop

DESCRIPTION="launcher for COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-launcher"

MY_PV="epoch-1.0.0-beta.5"

SRC_URI="
	https://github.com/pop-os/${PN}/archive/refs/tags/${MY_PV}.tar.gz -> ${PN}-${PV}.tar.gz
	https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${P}-crates.tar.zst
	"

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
	dobin "$(cosmic-de_target_dir)/$PN"

	domenu data/com.system76.CosmicLauncher.desktop

	cosmic-de_install_metainfo data/com.system76.CosmicLauncher.metainfo.xml

	insinto /usr/share/icons/hicolor/scalable/apps
	doins data/icons/com.system76.CosmicLauncher.svg
}
