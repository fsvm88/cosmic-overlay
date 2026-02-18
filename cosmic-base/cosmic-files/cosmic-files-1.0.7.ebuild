# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de-r2 desktop

DESCRIPTION="file manager from COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-files"

SRC_URI="https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${PN}-${PVR}.full.tar.zst"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"
IUSE+=" afp http nfs samba"

BDEPEND+="
	dev-libs/glib:2
	>=gnome-base/gvfs-1.48.0[afp?,http?,nfs?,samba?]
"
RDEPEND+="
	x11-misc/xdg-utils
	>=gnome-base/gvfs-1.48.0[afp?,http?,nfs?,samba?]
"

src_configure() {
	# Required for some crates to build properly due to build.rs scripts
	export VERGEN_GIT_COMMIT_DATE='Tue Feb 17 12:06:25 2026 -0700'
	export VERGEN_GIT_SHA=eda673a2585f934f6655cd18bb3c699ad8b077f6

	cosmic-de-r2_src_configure
}

src_compile() {
	cosmic-de-r2_src_compile
	cosmic-de-r2_src_compile --package "$PN-applet"
}

src_install() {
	dobin "$(cosmic-common_target_dir)/$PN"
	dobin "$(cosmic-common_target_dir)/$PN-applet"

	domenu target/xdgen/com.system76.CosmicFiles.desktop

	cosmic-common_install_metainfo target/xdgen/com.system76.CosmicFiles.metainfo.xml

	insinto /usr/share/icons/hicolor
	doins -r res/icons/hicolor/*
}
