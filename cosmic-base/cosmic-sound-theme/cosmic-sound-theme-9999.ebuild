# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

DESCRIPTION="COSMIC DE Sound Theme"
HOMEPAGE="https://github.com/pop-os/cosmic-sound-theme"

EGIT_LFS=1
inherit git-r3
EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH=master
# Look for EGIT_MIN_CLONE_TYPE variable in cosmic-live.eclass.
# TL;DR: this costs some additional DISTDIR space,
# but is the only way to re-use the same DISTDIR for multiple ebuilds.
EGIT_MIN_CLONE_TYPE=mirror
EGIT_LFS_CLONE_TYPE=mirror

# use cargo-license for a more accurate license picture
LICENSE="CC-BY-SA-4.0"
SLOT="0"
KEYWORDS=""

src_prepare() {
	default

	sed -e 's/@ThemeName@/COSMIC/' src/index.theme.in > src/index.theme
}

src_install() {
	insinto /usr/share/sounds/COSMIC
	doins src/index.theme
	doins -r src/stereo
}
