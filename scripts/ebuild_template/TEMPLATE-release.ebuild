# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de-r2

DESCRIPTION="@DESCRIPTION@"
HOMEPAGE="https://github.com/pop-os/${PN}"

SRC_URI="https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${PN}-${PV}.full.tar.zst"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

src_configure() {
	cosmic-de-r2_src_configure --all
}

src_install() {
	dobin "$(cosmic-common_target_dir)/$PN"
}
