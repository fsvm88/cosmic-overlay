# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

RUST_MIN_VER="1.85.0"
RUST_MAX_VER="1.92.0"
inherit cosmic-de desktop

DESCRIPTION="A tweaking tool offering access to advanced settings and features for COSMIC DE"
HOMEPAGE="https://github.com/cosmic-utils/tweaks"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH="main"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

BDEPEND+="
	dev-vcs/git
	dev-util/pkgconf
	virtual/pkgconfig
"

src_install() {
	export APPID="dev.edfloreshz.CosmicTweaks"

	exeinto /usr/bin
	doexe "$(cosmic-de_target_dir)/cosmic-ext-tweaks"

	newicon -s scalable res/icons/hicolor/scalable/apps/icon.svg ${APPID}.svg

	newmenu res/app.desktop ${APPID}.desktop

	insinto /usr/share/metainfo
	newins res/metainfo.xml ${APPID}.metainfo.xml
}
