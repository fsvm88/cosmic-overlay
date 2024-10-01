# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

DESCRIPTION="AppStream data for COSMIC DE"

HOMEPAGE="https://github.com/pop-os/appstream-data"

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
RDEPEND="
>=dev-libs/appstream-0.16.4
"

src_install() {
	insinto /usr/share/app-info/yaml
	doins dest/*.gz

	insinto /usr/share/app-info/icons/pop-artful-extra/128x128
	doins -r dest/icons/128x128/*

	insinto /usr/share/app-info/icons/pop-artful-extra/64x64/
	doins -r dest/icons/64x64/*
}
