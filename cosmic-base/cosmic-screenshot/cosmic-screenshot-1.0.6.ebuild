# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de-r2 desktop

DESCRIPTION="utility for capturing screenshots via XDG Desktop Portal from COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-screenshot"

SRC_URI="https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${PN}-${PVR}.full.tar.zst"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND+="
	>=cosmic-base/xdg-desktop-portal-cosmic-${PV}
"

src_install() {
	dobin "$(cosmic-de-r2_target_dir)/$PN"

	domenu resources/com.system76.CosmicScreenshot.desktop

	insinto /usr/share/icons/hicolor
	doins -r resources/icons/hicolor/*
}
