# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de-r2 desktop

DESCRIPTION="app store from COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-store"

SRC_URI="https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${PN}-${PVR}.full.tar.zst"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND+="
	>=dev-libs/openssl-3.0.13-r2
	>=sys-apps/flatpak-1.14.4-r3
	~cosmic-base/pop-appstream-data-9999
	~cosmic-base/cosmic-icons-${PV}
"

src_install() {
	dobin "$(cosmic-common_target_dir)/$PN"

	domenu res/com.system76.CosmicStore.desktop

	cosmic-common_install_metainfo res/com.system76.CosmicStore.metainfo.xml

	insinto /usr/share/icons/hicolor
	doins -r res/icons/hicolor/*
}
