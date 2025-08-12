# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de desktop

DESCRIPTION="file manager from COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-files"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH=master

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS=""
IUSE+=" ${COSMIC_DE_GVFS_IUSE}"

BDEPEND+="
	dev-libs/glib:2
	${COSMIC_DE_GVFS_DEPENDS}
"
RDEPEND+="
	x11-misc/xdg-utils
	${COSMIC_DE_GVFS_DEPENDS}
"

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
