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
	export VERGEN_GIT_COMMIT_DATE='Tue Apr 14 09:52:22 2026 -0600'
	export VERGEN_GIT_SHA=5e0392be0434c8f23a95b9f1c14cc0d02395ec89

	cosmic-de-r2_src_configure
}

src_install() {
	dobin "$(cosmic-common_target_dir)/$PN"

	domenu target/xdgen/com.system76.CosmicEdit.desktop

	cosmic-common_install_metainfo target/xdgen/com.system76.CosmicEdit.metainfo.xml

	insinto /usr/share/icons/hicolor
	doins -r res/icons/hicolor/*
}
