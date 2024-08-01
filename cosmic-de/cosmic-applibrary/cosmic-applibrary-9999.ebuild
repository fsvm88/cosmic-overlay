# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de desktop

DESCRIPTION="app library for COSMIC DE"
HOMEPAGE="https://github.com/pop-os/$PN"

if [ "${PV}" == "9999" ]; then
	EGIT_REPO_URI="${HOMEPAGE}"
	EGIT_COMMIT=5323a09
else
	# TODO this is not really working atm
	SRC_URI="https://github.com/pop-os/${PN}/archive/refs/tags/${MY_PV}.tar.gz -> ${P}.tar.gz
				$(cargo_crate_uris)
"
fi

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

src_install() {
	# One of the few where $PN does not apply (would be cosmic-applibrary)
	dobin "target/$profile_name/cosmic-app-library"

	domenu data/com.system76.CosmicAppLibrary.desktop

	cosmic-de_install_metainfo data/com.system76.CosmicAppLibrary.metainfo.xml

	insinto /usr/share/icons/hicolor/scalable/apps
	doins data/icons/com.system76.CosmicAppLibrary.svg
}
