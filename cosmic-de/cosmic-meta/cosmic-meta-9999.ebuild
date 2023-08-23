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
=cosmic-de/cosmic-applets-9999
=cosmic-de/cosmic-bg-9999
=cosmic-de/cosmic-comp-9999
=cosmic-de/cosmic-icons-9999
=cosmic-de/cosmic-launcher-9999
=cosmic-de/cosmic-notifications-9999
=cosmic-de/cosmic-osd-9999
=cosmic-de/cosmic-panel-9999
=cosmic-de/cosmic-session-9999
=cosmic-de/cosmic-settings-9999
=cosmic-de/cosmic-settings-daemon-9999
=cosmic-de/cosmic-text-editor-9999
=cosmic-de/cosmic-workspaces-epoch-9999
=cosmic-de/xdg-desktop-portal-cosmic-9999
"
