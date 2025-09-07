# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8
inherit meson

DESCRIPTION="PopOS icon theme for COSMIC DE"

HOMEPAGE="https://github.com/pop-os/icon-theme"

LICENSE="CC-BY-SA-4.0"
SLOT="0"
KEYWORDS="~amd64"

EGIT_LFS=1
inherit git-r3
EGIT_MIN_CLONE_TYPE=mirror
EGIT_LFS_CLONE_TYPE=mirror
EGIT_REPO_URI="${HOMEPAGE}"
EGIT_COMMIT="v3.5.1"

BDEPEND="
>=dev-build/meson-1.3.2
"
RDEPEND="
>=x11-themes/adwaita-icon-theme-45.0
>=x11-themes/hicolor-icon-theme-0.17
"
