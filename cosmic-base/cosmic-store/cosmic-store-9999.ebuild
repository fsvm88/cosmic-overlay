# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de desktop

DESCRIPTION="app store from COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-store"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH=master

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS=""

#### TODO apt-config-icons{-hidpi,-large,-large-hidpi} - are these really required?
RDEPEND+="
	>=dev-libs/openssl-3.0.13-r2
	>=sys-apps/flatpak-1.14.4-r3
	~cosmic-base/pop-appstream-data-9999
	~cosmic-base/cosmic-icons-${PV}
"

src_install() {
	dobin "target/$profile_name/$PN"

	domenu res/com.system76.CosmicStore.desktop

	cosmic-de_install_metainfo res/com.system76.CosmicStore.metainfo.xml

	insinto /usr/share/icons/hicolor
	doins -r res/icons/hicolor/*
}
