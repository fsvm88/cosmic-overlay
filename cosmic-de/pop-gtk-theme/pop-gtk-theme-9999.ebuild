# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8
inherit meson

DESCRIPTION="PopOS GTK theme for COSMIC DE"

HOMEPAGE="https://github.com/pop-os/gtk-theme"

LICENSE=""
SLOT="0"
KEYWORDS="~amd64"

if [ ${PV} == "9999" ] ; then
	inherit git-r3
	EGIT_REPO_URI="${HOMEPAGE}"
fi
IUSE=""

#RDEPEND=""
#DEPEND="${RDEPEND}"
BDEPEND="
dev-build/meson
dev-build/ninja
dev-lang/sassc
dev-libs/glib
"

