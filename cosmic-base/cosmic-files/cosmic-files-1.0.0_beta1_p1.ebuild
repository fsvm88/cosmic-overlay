# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de desktop

DESCRIPTION="file manager from COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-files"

MY_PV="epoch-1.0.0-beta.1.1"

SRC_URI="
	https://github.com/pop-os/${PN}/archive/refs/tags/${MY_PV}.tar.gz -> ${PN}-${PV}.tar.gz
	https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${P}-crates.tar.zst
	"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"
IUSE+=" ${COSMIC_DE_GVFS_IUSE}"

BDEPEND+="
	dev-libs/glib:2
	${COSMIC_DE_GVFS_DEPENDS}
"
RDEPEND+="
	x11-misc/xdg-utils
	${COSMIC_DE_GVFS_DEPENDS}
"

src_configure() {
	# Required for some crates to build properly due to build.rs scripts
	export VERGEN_GIT_COMMIT_DATE='Wed Sep 24 14:23:41 2025 -0600'
	export VERGEN_GIT_SHA=0c222e1e3a9da73c32240858c3dafc81956396f0

	cosmic-de_src_configure
}

src_compile() {
	cosmic-de_src_compile
	cosmic-de_src_compile --package "$PN-applet"
}

src_install() {
	dobin "$(cosmic-de_target_dir)/$PN"
	dobin "$(cosmic-de_target_dir)/$PN-applet"

	domenu res/com.system76.CosmicFiles.desktop

	cosmic-de_install_metainfo res/com.system76.CosmicFiles.metainfo.xml

	insinto /usr/share/icons/hicolor
	doins -r res/icons/hicolor/*
}
