# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

EGIT_LFS=1

DESCRIPTION="Wallpapers for the COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-wallpapers"

inherit git-r3
EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH=master

BDEPEND="
	media-gfx/imagemagick
"

# As of 2024-11-01, the git repo now provides a LICENSE
LICENSE="CC-BY-SA-4.0"
SLOT="0"
KEYWORDS="~amd64"

src_unpack() {
	# if [[ "${PV}" == *9999* ]]; then
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
