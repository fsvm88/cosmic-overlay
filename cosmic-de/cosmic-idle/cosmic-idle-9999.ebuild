# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

COSMIC_GIT_UNPACK=1
inherit cosmic-de

DESCRIPTION="screen idle daemon for COSMIC DE"
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

src_configure() {
	cosmic-de_src_configure --all
}

src_install() {
	dobin "target/$profile_name/$PN"
}
