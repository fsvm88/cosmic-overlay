# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

RUST_MIN_VER="1.88.0"
RUST_MAX_VER="1.92.0"
inherit cosmic-de desktop

DESCRIPTION="Minimon COSMIC DE Applet"
HOMEPAGE="https://github.com/cosmic-utils/minimon-applet"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH="main"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

# observatory system monitor repository is archived, using gnome-system-monitor instead.
RDEPEND+="
	gnome-extra/gnome-system-monitor
"

BDEPEND="
	dev-vcs/git
	dev-util/pkgconf
	virtual/pkgconfig
"

src_install() {
	exeinto /usr/bin
	doexe "$(cosmic-de_target_dir)/cosmic-applet-minimon"

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
