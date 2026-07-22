# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-live

DESCRIPTION="COSMIC DE Sound Theme"
HOMEPAGE="https://github.com/pop-os/cosmic-sound-theme"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH=master

# use cargo-license for a more accurate license picture
LICENSE="CC-BY-SA-4.0"
SLOT="0"
KEYWORDS=""

src_prepare() {
	cosmic-live_src_prepare
	sed -e 's/@ThemeName@/COSMIC' src/index.theme.in > src/index.theme
}

src_install() {
	insinto /usr/share/sounds/COSMIC
	doins src/index.theme
	doins -r src/stereo
}
