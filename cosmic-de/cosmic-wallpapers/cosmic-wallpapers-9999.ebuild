# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

EGIT_LFS=1

DESCRIPTION="Wallpapers for the COSMIC DE"
HOMEPAGE="https://github.com/pop-os/$PN"

inherit git-r3
EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH=master

BDEPEND="
	media-gfx/imagemagick
"

LICENSE="Unknown"
SLOT="0"
KEYWORDS="~amd64"

if [[ ${PV} == 9999 ]]; then
	KEYWORDS=""
fi

src_unpack() {
	if [[ "${PV}" == *9999* ]]; then
		git-r3_src_unpack
	else
		if [[ -n ${A} ]]; then
			unpack "${A}"
		fi
	fi
}

src_install() {
	insinto /usr/share/backgrounds/cosmic
	doins original/*
}
