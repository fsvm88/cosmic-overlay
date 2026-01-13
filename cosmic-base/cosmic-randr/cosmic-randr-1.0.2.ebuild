# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de

DESCRIPTION="CLI utility for displaying and configuring wayland outputs from COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-randr"

MY_PV="epoch-1.0.2"

SRC_URI="
	https://github.com/pop-os/${PN}/archive/refs/tags/${MY_PV}.tar.gz -> ${PN}-${PV}.tar.gz
	https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${P}-crates.tar.zst
	"

# use cargo-license for a more accurate license picture
LICENSE="MPL-2.0"
SLOT="0"
KEYWORDS="~amd64"

src_install() {
	dobin "$(cosmic-de_target_dir)/$PN"
}
