# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de-r2 desktop

DESCRIPTION="terminal emulator (built using alacritty_terminal) from COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-term"


SRC_URI="https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${PN}-${PVR}.full.tar.zst"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND+="
	>=cosmic-base/cosmic-icons-${PV}
"

src_configure() {
	# Required for some crates to build properly due to build.rs scripts
	export VERGEN_GIT_COMMIT_DATE='Mon Feb 9 14:35:57 2026 -0700'
	export VERGEN_GIT_SHA=93c25f46a959cdb60eadabf90b5e8a610c540f57

	cosmic-de-r2_src_configure
}

src_install() {
	dobin "$(cosmic-de-r2_target_dir)/$PN"

	domenu res/com.system76.CosmicTerm.desktop

	cosmic-de-r2_install_metainfo res/com.system76.CosmicTerm.metainfo.xml

	insinto /usr/share/icons/hicolor
	doins -r res/icons/hicolor/*
}
