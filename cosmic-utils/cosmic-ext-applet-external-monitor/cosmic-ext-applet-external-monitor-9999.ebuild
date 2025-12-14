# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

RUST_MIN_VER="1.85.0"
RUST_MAX_VER="1.92.0"
inherit cargo desktop git-r3 xdg-utils

DESCRIPTION="External Monitor Brightness Applet for the COSMIC™ desktop"
HOMEPAGE="https://github.com/cosmic-utils/cosmic-ext-applet-external-monitor-brightness"
SRC_URI=""
# The actual license needs verification with 'cargo license' in the source directory.
LICENSE="GPL-3.0"

SLOT="0"
KEYWORDS="~amd64" # Adjust keywords as necessary for your architecture

DEPEND="
	app-misc/ddcutil
"

RDEPEND="${DEPEND}"

BDEPEND="
	dev-vcs/git
	dev-util/pkgconf
	virtual/pkgconfig
"

# Source code fetched via git-r3 eclass
# Ensure this matches the repository URL from the GitHub link
EGIT_REPO_URI="https://github.com/cosmic-utils/cosmic-ext-applet-external-monitor-brightness.git"
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
	doexe "$(cargo_target_dir)/cosmic-ext-applet-external-monitor-brightness"

#	insinto /usr/share/icons/hicolor/scalable/apps
	insinto /usr/share/icons/hicolor/symbolic/apps
	doicon res/icons/cosmic-applet-battery-display-brightness-high-symbolic.svg
	doicon res/icons/cosmic-applet-battery-display-brightness-low-symbolic.svg
	doicon res/icons/cosmic-applet-battery-display-brightness-medium-symbolic.svg
	doicon res/icons/cosmic-applet-battery-display-brightness-off-symbolic.svg
	doicon res/icons/display-symbolic.svg

	newmenu res/desktop_entry.desktop io.github.cosmic_utils.cosmic-ext-applet-external-monitor-brightness.desktop

	insinto /usr/share/metainfo
	newins res/metainfo.xml io.github.cosmic_utils.cosmic-ext-applet-external-monitor-brightness.metainfo.xml
}

pkg_postinst() {
	xdg_icon_cache_update
}
