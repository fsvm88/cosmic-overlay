# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de

DESCRIPTION="compositor for COSMIC DE"
HOMEPAGE="https://github.com/pop-os/$PN"

if [ "${PV}" == "9999" ]; then
	EGIT_REPO_URI="${HOMEPAGE}"
	EGIT_COMMIT=4748916
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

# As per https://raw.githubusercontent.com/pop-os/cosmic-comp/master/debian/control
DEPEND="
	${DEPEND}
	>=media-libs/fontconfig-2.14.2-r3
	>=media-libs/mesa-24.0.4
	>=sys-auth/seatd-0.8.0
	>=x11-libs/libxcb-1.16.1
	>=x11-libs/pixman-0.43.4
"

src_install() {
	dobin "target/$profile_name/$PN"
}
