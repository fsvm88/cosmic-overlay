# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

EGIT_LFS=1

DESCRIPTION="Wallpapers for the COSMIC DE"
HOMEPAGE="https://github.com/pop-os/$PN"

if [ "${PV}" == "9999" ]; then
	inherit git-r3
	EGIT_REPO_URI="${HOMEPAGE}"
	# Not sure if there's any sense in this NOT pointing to master
	# EGIT_COMMIT=f93dcdf
else
	# TODO this is not really working atm
	SRC_URI="https://github.com/pop-os/${PN}/archive/refs/tags/${MY_PV}.tar.gz -> ${P}.tar.gz
				$(cargo_crate_uris)
"
fi

BDEPEND="
	media-gfx/imagemagick
"

LICENSE="Unknown"
SLOT="0"
KEYWORDS="~amd64"

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
