# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de-r2 desktop

DESCRIPTION="file manager from COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-files"

SRC_URI="https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${PN}-${PV}.full.tar.zst"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"
IUSE+=" afp http mtp nfs samba"

DEPEND+="
	dev-libs/glib:2
"
RDEPEND+="
	${DEPEND}
	x11-misc/xdg-utils
	>=gnome-base/gvfs-1.48.0[afp?,http?,mtp?,nfs?,samba?]
	=cosmic-base/cosmic-icons-$(ver_cut 1-2)*
"

src_configure() {
	# Required for some crates to build properly due to build.rs scripts
	export VERGEN_GIT_COMMIT_DATE='Tue Oct 6 21:53:02 2026 +0200'
	export VERGEN_GIT_SHA=ac5cef76fa60b5a329bfda3d30825489ec28af53

	cosmic-de-r2_src_configure
}

src_compile() {
	cosmic-de-r2_src_compile
	cosmic-de-r2_src_compile --package "$PN-applet"
	cosmic-de-r2_src_compile --package "$PN-thumbnailer"
}

src_install() {
	dobin "$(cosmic-common_target_dir)/$PN"
	dobin "$(cosmic-common_target_dir)/$PN-applet"
	dobin "$(cosmic-common_target_dir)/$PN-thumbnailer"

	domenu target/xdgen/com.system76.CosmicFiles.desktop

	cosmic-common_install_metainfo target/xdgen/com.system76.CosmicFiles.metainfo.xml

	insinto /usr/share/icons/hicolor
	doins -r res/icons/hicolor/*

	insinto /usr/share/thumbnailers
	doins res/com.system76.CosmicFiles.thumbnailer
}
