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

	export APPID="io.github.cosmic_utils.minimon-applet"

	doicon -s scalable res/icons/apps/*.svg

	domenu res/${APPID}.desktop

	cosmic-de_install_metainfo res/${APPID}.metainfo.xml
}
