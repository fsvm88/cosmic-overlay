# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de desktop

DESCRIPTION="app store from COSMIC DE"
HOMEPAGE="https://github.com/pop-os/$PN"

if [ "${PV}" == "9999" ]; then
	EGIT_REPO_URI="${HOMEPAGE}"
	EGIT_COMMIT=4d1a592
else
	SRC_URI="https://github.com/${PN}/${PN}/archive/refs/tags/v${MY_PV}.tar.gz -> ${P}.tar.gz
			$(cargo_crate_uris)"
fi

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

# As per https://raw.githubusercontent.com/pop-os/cosmic-store/master/debian/control
DEPEND="
	${DEPEND}
	>=dev-libs/openssl-3.0.13-r2
	>=sys-apps/flatpak-1.14.4-r3
"
RDEPEND="
	${RDEPEND}
	=cosmic-de/pop-appstream-data-${PV}
"

src_install() {
	dobin "target/$profile_name/$PN"

	domenu res/com.system76.CosmicStore.desktop

	cosmic-de_install_metainfo res/com.system76.CosmicStore.metainfo.xml

	insinto /usr/share/icons/hicolor
	doins -r res/icons/hicolor/*
}
