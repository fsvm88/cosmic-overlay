# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

COSMIC_GIT_UNPACK=1
inherit cosmic-de desktop

DESCRIPTION="utility for capturing screenshots via XDG Desktop Portal from COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-screenshot"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_COMMIT="epoch-1.0.0-alpha.4"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

# As per https://raw.githubusercontent.com/pop-os/cosmic-screenshot/master/debian/control
RDEPEND="
	${RDEPEND}
	>=cosmic-de/xdg-desktop-portal-cosmic-${PV}
"

src_install() {
	dobin "target/$profile_name/$PN"

	domenu resources/com.system76.CosmicScreenshot.desktop

	insinto /usr/share/icons/hicolor
	doins -r resources/icons/hicolor/*
}
