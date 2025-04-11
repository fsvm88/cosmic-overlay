# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

EGIT_LFS=1

DESCRIPTION="Wallpapers for the COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-wallpapers"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_COMMIT="epoch-1.0.0-alpha.7"
inherit git-r3

BDEPEND="
	media-gfx/imagemagick
"

# As of 2024-11-01, the git repo now provides a LICENSE
LICENSE="CC-BY-SA-4.0"
SLOT="0"
KEYWORDS="~amd64"

src_unpack() {
	# if [[ "${PV}" == *1.0.0_alpha7* ]]; then
	git-r3_src_unpack
	# else
	# 	if [[ -n ${A} ]]; then
	# 		unpack "${A}"
	# 	fi
	# fi
}

src_install() {
	insinto /usr/share/backgrounds/cosmic
	doins original/*
}
