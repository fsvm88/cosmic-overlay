# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de-r2

DESCRIPTION="panel for COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-panel"

SRC_URI="https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${PN}-${PVR}.full.tar.zst"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

src_install() {
	dobin "$(cosmic-common_target_dir)/$PN"

	insinto /usr/share/cosmic
	doins -r data/default_schema/*
}
