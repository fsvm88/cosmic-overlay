# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Meta package for cosmic-de"
HOMEPAGE="https://github.com/pop-os/cosmic-epoch"
SRC_URI=""
# This is a meta package, trying to include most of the licenses used by sub-packages, but no guarantee
# Not sure how/if this should be handled better
LICENSE="0BSD Apache-2.0 Apache-2.0-with-LLVM-exceptions Artistic-2 BSD BSD-2 Boost-1.0 CC0-1.0 GPL-3 GPL-3+ ISC MIT MPL-2.0 OFL-1.1 Unicode-DFS-2016 Unlicense ZLIB"

SLOT="0"
KEYWORDS="~amd64"
IUSE=""

RDEPEND="
=cosmic-de/cosmic-applets-${PV}
=cosmic-de/cosmic-applibrary-${PV}
=cosmic-de/cosmic-bg-${PV}
=cosmic-de/cosmic-comp-${PV}
=cosmic-de/cosmic-edit-${PV}
=cosmic-de/cosmic-files-${PV}
=cosmic-de/cosmic-greeter-${PV}
=cosmic-de/cosmic-icons-${PV}
=cosmic-de/cosmic-launcher-${PV}
=cosmic-de/cosmic-notifications-${PV}
=cosmic-de/cosmic-osd-${PV}
=cosmic-de/cosmic-panel-${PV}
=cosmic-de/cosmic-randr-${PV}
=cosmic-de/cosmic-screenshot-${PV}
=cosmic-de/cosmic-session-${PV}
=cosmic-de/cosmic-settings-${PV}
=cosmic-de/cosmic-settings-daemon-${PV}
=cosmic-de/cosmic-store-${PV}
=cosmic-de/cosmic-term-${PV}
=cosmic-de/cosmic-text-editor-${PV}
=cosmic-de/cosmic-workspaces-epoch-${PV}
=cosmic-de/pop-theme-meta-${PV}
=cosmic-de/xdg-desktop-portal-cosmic-${PV}
"
