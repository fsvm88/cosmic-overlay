# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

DESCRIPTION="icon set COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-icons"

inherit git-r3
EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH=master

# use cargo-license for a more accurate license picture
LICENSE="CC-BY-SA-4.0"
SLOT="0"
KEYWORDS=""

RDEPEND+="
	>=cosmic-base/pop-icon-theme-3.5.1
"

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
	insinto /usr/share/icons/Cosmic
	doins -r freedesktop/scalable
	doins -r extra/scalable
	doins index.theme
}
