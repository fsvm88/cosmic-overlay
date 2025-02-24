# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

EGIT_LFS=1

DESCRIPTION="Wallpapers for the COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-wallpapers"

inherit git-r3
EGIT_REPO_URI="${HOMEPAGE}"
EGIT_COMMIT="epoch-1.0.0-alpha.6"
# Due to the way things are setup at the moment, we reuse the same `DISTDIR`
# repo for multiple versions (e.g.: alpha2 -> alpha3 -> alpha4).
# 
# Problem is that every time we emerge a new version, the repo with
# `CLONE_TYPE=single` does not contain all other refs and is not reset, so the
# user needs to manually remove it and reclone it.
# 
# While `CLONE_TYPE=mirror` increases repo size, for cosmic-wallpaper it takes
# ~18MB. It's still better for the user to cleanup once/year (or whenever)
# instead of every time a new version hits the repo. Old/deleted refs are
# purged in this mode.
EGIT_CLONE_TYPE=mirror
EGIT_LFS_CLONE_TYPE=mirror

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
