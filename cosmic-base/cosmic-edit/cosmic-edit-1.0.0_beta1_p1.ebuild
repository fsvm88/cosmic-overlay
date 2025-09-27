# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de desktop

DESCRIPTION="text editor from COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-edit"

MY_PV="epoch-1.0.0-beta.1.1"

SRC_URI="
	https://github.com/pop-os/${PN}/archive/refs/tags/${MY_PV}.tar.gz -> ${PN}-${PV}.tar.gz
	https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${PF}-crates.tar.zst
	"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

src_configure() {
	# Required for some crates to build properly due to build.rs scripts
	export VERGEN_GIT_COMMIT_DATE='Wed Sep 24 14:23:14 2025 -0600'
	export VERGEN_GIT_SHA=942cfc4f27f7e9d57ac09c576be75ff9458a4e67

	cosmic-de_src_configure
}

src_install() {
	dobin "$(cosmic-de_target_dir)/$PN"

	domenu res/com.system76.CosmicEdit.desktop

	cosmic-de_install_metainfo res/com.system76.CosmicEdit.metainfo.xml

	insinto /usr/share/icons/hicolor
	doins -r res/icons/hicolor/*
}
