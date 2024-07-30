# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de desktop

DESCRIPTION="launcher for COSMIC DE"
HOMEPAGE="https://github.com/pop-os/$PN"

if [ "${PV}" == "9999" ]; then
	EGIT_REPO_URI="${HOMEPAGE}"
	EGIT_COMMIT=96d9042
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

# As per https://raw.githubusercontent.com/pop-os/cosmic-launcher/master/debian/control
BDEPEND="
		${BDEPEND}
		>=dev-util/intltool-0.51.0-r3
"
RDEPEND="
		${RDEPEND}
		=cosmic-de/pop-launcher-${PV}
"

src_install() {
	dobin "target/$profile_name/$PN"

	domenu data/com.system76.CosmicLauncher.desktop

	cosmic-de_install_metainfo data/com.system76.CosmicLauncher.metainfo.xml

	insinto /usr/share/icons/hicolor/scalable/apps
	doins data/icons/com.system76.CosmicLauncher.svg
}
