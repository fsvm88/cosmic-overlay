# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de desktop

DESCRIPTION="terminal emulator (built using alacritty_terminal) from COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-term"

MY_PV="epoch-1.0.4"

SRC_URI="
	https://github.com/pop-os/${PN}/archive/refs/tags/${MY_PV}.tar.gz -> ${PN}-${PV}.tar.gz
	https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${P}-crates.tar.zst
	"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND+="
	>=cosmic-base/cosmic-icons-${PV}
"

src_configure() {
	# Required for some crates to build properly due to build.rs scripts
	export VERGEN_GIT_COMMIT_DATE='Tue Jan 27 10:20:03 2026 -0700'
	export VERGEN_GIT_SHA=cdeaeeddc930ae9e2901377e6faf414c2767bc13

	cosmic-de_src_configure
}

src_install() {
	dobin "$(cosmic-de_target_dir)/$PN"

	domenu res/com.system76.CosmicTerm.desktop

	cosmic-de_install_metainfo res/com.system76.CosmicTerm.metainfo.xml

	insinto /usr/share/icons/hicolor
	doins -r res/icons/hicolor/*
}
