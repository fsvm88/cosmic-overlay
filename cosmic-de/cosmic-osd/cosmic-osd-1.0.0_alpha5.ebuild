# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

COSMIC_GIT_UNPACK=1
inherit cosmic-de

DESCRIPTION="OSD daemon for COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-osd"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_COMMIT="epoch-1.0.0-alpha.5"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

# As per https://raw.githubusercontent.com/pop-os/cosmic-osd/master/debian/control
RDEPEND="
	${RDEPEND}
	>=media-libs/libpulse-17.0
	>=virtual/libudev-251-r2
"

src_install() {
	dobin "target/$profile_name/$PN"
}
