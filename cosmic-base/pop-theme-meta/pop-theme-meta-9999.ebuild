# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8
DESCRIPTION="Meta package for PopOS theme packages"
HOMEPAGE="https://github.com/pop-os/theme"

LICENSE="CC-BY-SA-4.0 OFL-1.1"
SLOT="0"
KEYWORDS="~amd64"

IUSE="gtk-theme"
RDEPEND="
~cosmic-base/pop-fonts-${PV}
>=cosmic-base/pop-icon-theme-3.5.1
gtk-theme? ( ~cosmic-base/pop-gtk-theme-${PV} )
"
