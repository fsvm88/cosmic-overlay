# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de desktop

DESCRIPTION="utility for capturing screenshots via XDG Desktop Portal from COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-screenshot"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH=master

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS=""

RDEPEND+="
	>=cosmic-base/xdg-desktop-portal-cosmic-${PV}
"

src_install() {
	dobin "target/$profile_name/$PN"

	domenu resources/com.system76.CosmicScreenshot.desktop

	insinto /usr/share/icons/hicolor
	doins -r resources/icons/hicolor/*
}
