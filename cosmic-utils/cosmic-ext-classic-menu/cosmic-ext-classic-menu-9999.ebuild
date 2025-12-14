# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

RUST_MIN_VER="1.85.0"
RUST_MAX_VER="1.92.0"
inherit cargo desktop git-r3 xdg-utils

DESCRIPTION="Classic Menu is a customizable application launcher for the COSMIC™ desktop environment. It provides a classic style menu for launching applications, accessing system tools, and managing power options."
HOMEPAGE="https://github.com/championpeak87/cosmic-ext-classic-menu"
SRC_URI=""
# The actual license needs verification with 'cargo license' in the source directory.
LICENSE="GPL-3.0"

SLOT="0"
KEYWORDS="~amd64" # Adjust keywords as necessary for your architecture

DEPEND="
"

RDEPEND="${DEPEND}"

BDEPEND="
	dev-vcs/git
	app-portage/pkgconf
	virtual/pkgconfig
"

# Source code fetched via git-r3 eclass
# Ensure this matches the repository URL from the GitHub link
EGIT_REPO_URI="https://github.com/championpeak87/cosmic-ext-classic-menu.git"
# Use the master branch or specify a different one
GIT_BBRANCH="master"

# Gentoo's cargo eclass handles most of the build process.
# We override the compile and install phases to use 'just' as requested,
# ensuring it operates within the Portage sandbox (${ED}).

src_unpack() {
	git-r3_src_unpack
	cargo_live_src_unpack
}

src_configure() {
	cargo_src_configure --no-default-features
}

src_compile() {
	cargo_src_compile
}

src_install() {
	exeinto /usr/bin
	doexe "$(cargo_target_dir)/cosmic-ext-classic-menu-applet"
	doexe "$(cargo_target_dir)/cosmic-ext-classic-menu-settings"

	insinto /usr/share/icons/hicolor/scalable/apps
	doicon -s scalable res/icons/hicolor/scalable/apps/com.championpeak87.cosmic-ext-classic-menu.svg

	domenu res/com.championpeak87.cosmic-ext-classic-menu.desktop

	insinto /usr/share/metainfo
	doins res/com.championpeak87.cosmic-ext-classic-menu.metainfo.xml
}

pkg_postinst() {
	xdg_icon_cache_update
}
