# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8
DESCRIPTION="Meta package for PopOS theme packages"
HOMEPAGE="https://github.com/pop-os/theme"

LICENSE="CC-BY-SA-4.0 OFL-1.1"
SLOT="0"
KEYWORDS="~amd64"
IUSE=""
RDEPEND="
=cosmic-de/pop-fonts-${PV}
=cosmic-de/pop-gtk-theme-${PV}
=cosmic-de/pop-icon-theme-${PV}
"
