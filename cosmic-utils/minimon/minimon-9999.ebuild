# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

RUST_MIN_VER="1.88.0"
RUST_MAX_VER="1.92.0"
inherit cargo desktop git-r3 xdg-utils

DESCRIPTION="Minimon COSMIC Applet"
HOMEPAGE="https://github.com/cosmic-utils/minimon-applet"
LICENSE="GPL-3"

SLOT="0"
KEYWORDS="~amd64"

# observatory system monitor repository is archived, using gnome-system-monitor instead.
DEPEND="
	gnome-extra/gnome-system-monitor
"

RDEPEND="${DEPEND}"

BDEPEND="
	dev-vcs/git
	dev-util/pkgconf
	virtual/pkgconfig
"

# Source code fetched via git-r3 eclass
# Ensure this matches the repository URL from the GitHub link
EGIT_REPO_URI="https://github.com/cosmic-utils/minimon-applet.git"
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
	doexe "$(cargo_target_dir)/cosmic-applet-minimon"

	insinto /usr/share/icons/hicolor/scalable/apps
	doicon -s scalable res/icons/apps/io.github.cosmic_utils.minimon-applet-cpu.svg
	doicon -s scalable res/icons/apps/io.github.cosmic_utils.minimon-applet-gpu.svg
	doicon -s scalable res/icons/apps/io.github.cosmic_utils.minimon-applet-harddisk.svg
	doicon -s scalable res/icons/apps/io.github.cosmic_utils.minimon-applet-network.svg
	doicon -s scalable res/icons/apps/io.github.cosmic_utils.minimon-applet-ram.svg
	doicon -s scalable res/icons/apps/io.github.cosmic_utils.minimon-applet.svg
	doicon -s scalable res/icons/apps/io.github.cosmic_utils.minimon-applet-temperature.svg

	domenu res/io.github.cosmic_utils.minimon-applet.desktop

	insinto /usr/share/metainfo
	doins res/io.github.cosmic_utils.minimon-applet.metainfo.xml
}

pkg_postinst() {
	xdg_icon_cache_update
}
