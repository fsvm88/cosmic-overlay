# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cosmic-de desktop

DESCRIPTION="COSMIC DE Privacy Indicator"
HOMEPAGE="https://github.com/D-Brox/cosmic-ext-applet-privacy-indicator"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH="master"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

BDEPEND+="
	dev-vcs/git
	dev-util/pkgconf
	virtual/pkgconfig
"

src_install() {
	exeinto /usr/bin
	doexe "$(cosmic-de_target_dir)/${PN}"

	export APPID="dev.DBrox.CosmicPrivacyIndicator"

	domenu res/${APPID}.desktop

	cosmic-de_install_metainfo res/${APPID}.metainfo.xml
}
