# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de desktop

DESCRIPTION="utility for capturing screenshots via XDG Desktop Portal from COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-screenshot"

MY_PV="epoch-1.0.0-beta.8"

SRC_URI="
	https://github.com/pop-os/${PN}/archive/refs/tags/${MY_PV}.tar.gz -> ${PN}-${PV}.tar.gz
	https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${P}-crates.tar.zst
	"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND+="
	>=cosmic-base/xdg-desktop-portal-cosmic-${PV}
"

src_install() {
	dobin "$(cosmic-de_target_dir)/$PN"

	domenu resources/com.system76.CosmicScreenshot.desktop

	insinto /usr/share/icons/hicolor
	doins -r resources/icons/hicolor/*
}
