# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de

DESCRIPTION="screen idle daemon for COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-idle"

MY_PV="epoch-1.0.3"

SRC_URI="
	https://github.com/pop-os/${PN}/archive/refs/tags/${MY_PV}.tar.gz -> ${PN}-${PV}.tar.gz
	https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${P}-crates.tar.zst
	"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

src_configure() {
	cosmic-de_src_configure --all
}

src_install() {
	dobin "$(cosmic-de_target_dir)/$PN"
}
