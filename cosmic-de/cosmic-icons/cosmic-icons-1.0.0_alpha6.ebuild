# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

DESCRIPTION="icon set COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-icons"

inherit git-r3
EGIT_REPO_URI="${HOMEPAGE}"
EGIT_COMMIT="epoch-1.0.0-alpha.6"

# use cargo-license for a more accurate license picture
LICENSE="CC-BY-SA-4.0"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND+="
	~cosmic-de/pop-icon-theme-${PV}
"

src_unpack() {
	if [[ "${PV}" == *1.0.0_alpha6* ]]; then
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
