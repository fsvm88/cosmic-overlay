# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

RUST_MIN_VER="1.85.0"
RUST_MAX_VER="1.92.0"
inherit cosmic-de desktop

DESCRIPTION="External Monitor Brightness Applet for the COSMIC DE"
HOMEPAGE="https://github.com/cosmic-utils/cosmic-ext-applet-external-monitor-brightness"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH="master"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND+="
	>=app-misc/ddcutil-2.2.0
"

BDEPEND+="
	dev-vcs/git
	dev-util/pkgconf
	virtual/pkgconfig
"

src_install() {
	export APPID="io.github.cosmic_utils.cosmic-ext-applet-external-monitor-brightness"

	exeinto /usr/bin
	doexe "$(cosmic-de_target_dir)/${PN}"

	doicon -s symbolic res/icons/display-symbolic.svg

	newmenu res/desktop_entry.desktop ${APPID}.desktop

	insinto /usr/share/metainfo
	newins res/metainfo.xml ${APPID}.metainfo.xml
}
