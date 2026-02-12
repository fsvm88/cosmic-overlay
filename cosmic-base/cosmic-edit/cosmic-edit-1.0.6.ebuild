# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de-r2 desktop

DESCRIPTION="text editor from COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-edit"

SRC_URI="https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${PN}-${PVR}.full.tar.zst"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

src_configure() {
	# Required for some crates to build properly due to build.rs scripts
	export VERGEN_GIT_COMMIT_DATE='Tue Feb 10 09:51:12 2026 -0700'
	export VERGEN_GIT_SHA=314f11ab89b436c481f8cf31762d55dc8d77bf8b

	cosmic-de-r2_src_configure
}

src_install() {
	dobin "$(cosmic-de-r2_target_dir)/$PN"

	domenu res/com.system76.CosmicEdit.desktop

	cosmic-de-r2_install_metainfo res/com.system76.CosmicEdit.metainfo.xml

	insinto /usr/share/icons/hicolor
	doins -r res/icons/hicolor/*
}
