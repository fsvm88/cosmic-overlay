# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de-r2

DESCRIPTION="COSMIC DE Sound Theme"
HOMEPAGE="https://github.com/pop-os/cosmic-sound-theme"

SRC_URI="https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${PN}-${PV}.full.tar.zst"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

src_prepare() {
	cosmic-de-r2_src_prepare
	sed -e 's/@ThemeName@/COSMIC' src/index.theme.in > src/index.theme
}

src_install() {
	insinto /usr/share/sounds/COSMIC
	doins src/index.theme
	doins -r src/stereo
}
