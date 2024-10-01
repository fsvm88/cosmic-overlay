# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

DESCRIPTION="PopOS fonts for COSMIC DE"

HOMEPAGE="https://github.com/pop-os/fonts"

LICENSE="OFL-1.1"
SLOT="0"
KEYWORDS="~amd64"

if [ "${PV}" == "9999" ]; then
	inherit git-r3
	EGIT_REPO_URI="${HOMEPAGE}"
	KEYWORDS=""
fi
IUSE=""

BDEPEND="
>=dev-build/make-4.4.1-r1
"
