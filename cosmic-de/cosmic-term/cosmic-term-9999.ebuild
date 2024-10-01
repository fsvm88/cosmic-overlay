# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de desktop

DESCRIPTION="terminal emulator (built using alacritty_terminal) from COSMIC DE"
HOMEPAGE="https://github.com/pop-os/$PN"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH=master

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

if [[ ${PV} == 9999 ]]; then
	KEYWORDS=""
fi

# As per https://raw.githubusercontent.com/pop-os/cosmic-term/master/debian/control
RDEPEND="
	${RDEPEND}
	>=cosmic-de/cosmic-icons-${PV}
"

src_install() {
	dobin "target/$profile_name/$PN"

	domenu res/com.system76.CosmicTerm.desktop

	cosmic-de_install_metainfo res/com.system76.CosmicTerm.metainfo.xml

	insinto /usr/share/icons/hicolor
	doins -r res/icons/hicolor/*
}
