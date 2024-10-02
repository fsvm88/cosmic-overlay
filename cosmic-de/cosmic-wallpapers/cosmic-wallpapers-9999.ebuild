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

# With help from: https://devmanual.gentoo.org/general-concepts/licenses/
# The files part of the package, referenced in the README ->
# https://github.com/pop-os/cosmic-wallpapers/blob/master/README.md
# either have CC-BY-4.0-INT -> CC-BY-4.0 (ESA images) or the license
# is not mentioned anywhere
# Go with the approach mentioned in the license page above -->
# all-rights-reserved, RESTRICT="bindist mirror"
LICENSE="CC-BY-4.0 all-rights-reserved"
RESTRICT="bindist mirror"
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
