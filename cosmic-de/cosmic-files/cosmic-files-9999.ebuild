# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de desktop

DESCRIPTION="file manager from COSMIC DE"
HOMEPAGE="https://github.com/pop-os/$PN"

if [ "${PV}" == "9999" ]; then
	EGIT_REPO_URI="${HOMEPAGE}"
	EGIT_COMMIT=190029a
	# to drop when tab_click_double_opens_folder will be fixed
	RESTRICT=test
else
	SRC_URI="https://github.com/${PN}/${PN}/archive/refs/tags/v${MY_PV}.tar.gz -> ${P}.tar.gz
			$(cargo_crate_uris)"
fi

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

BDEPEND="
	${BDEPEND}
	dev-libs/glib:2
"
RDEPEND="
	${RDEPEND}
	x11-misc/xdg-utils
"

src_install() {
	dobin "target/$profile_name/$PN"

	domenu res/com.system76.CosmicFiles.desktop

	cosmic-de_install_metainfo res/com.system76.CosmicFiles.metainfo.xml

	insinto /usr/share/icons/hicolor
	doins -r res/icons/hicolor/*
}
