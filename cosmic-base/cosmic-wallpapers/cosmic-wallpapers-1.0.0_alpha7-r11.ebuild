# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

DESCRIPTION="Wallpapers for the COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-wallpapers"

MY_PV="epoch-1.0.0-alpha.7"

SRC_URI="
	https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${PF}-repo.tar.zst
	"
MY_P="${PN}-${MY_PV}"
S="${WORKDIR}/${MY_P}"

# As of 2024-11-01, the git repo now provides a LICENSE
LICENSE="CC-BY-SA-4.0"
SLOT="0"
KEYWORDS="~amd64"

BDEPEND="
	media-gfx/imagemagick
"

src_install() {
	insinto /usr/share/backgrounds/cosmic
	doins original/*
}
