# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de-r2 desktop

DESCRIPTION="terminal emulator (built using alacritty_terminal) from COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-term"

SRC_URI="https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${PN}-${PV}.full.tar.zst"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND+="
	>=cosmic-base/cosmic-icons-${PV}
"

src_configure() {
	# Required for some crates to build properly due to build.rs scripts
	export VERGEN_GIT_COMMIT_DATE='Wed Sep 2 12:25:35 2026 -0600'
	export VERGEN_GIT_SHA=4f0f0b6e4ea478aed9b387365c0f03187e9301bd

	cosmic-de-r2_src_configure
}

src_install() {
	dobin "$(cosmic-common_target_dir)/$PN"

	domenu target/xdgen/com.system76.CosmicTerm.desktop

	cosmic-common_install_metainfo target/xdgen/com.system76.CosmicTerm.metainfo.xml

	insinto /usr/share/icons/hicolor
	doins -r res/icons/hicolor/*
}
