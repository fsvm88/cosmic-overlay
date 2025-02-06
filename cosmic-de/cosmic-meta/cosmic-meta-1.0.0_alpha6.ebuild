# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

DESCRIPTION="Meta package for cosmic-de"
HOMEPAGE="https://github.com/pop-os/cosmic-epoch"

# Updated ebuilds at 2eadc4e 20.04.2024
# This is a meta package, trying to include most of the licenses used by sub-packages, but no guarantee
# Not sure how/if this should be handled better
LICENSE="CC-BY-SA-4.0 GPL-3 GPL-3+ MPL-2.0"

SLOT="0"
KEYWORDS="~amd64"
IUSE="+greeter store"

RDEPEND="
~cosmic-de/cosmic-applets-${PV}
~cosmic-de/cosmic-applibrary-${PV}
~cosmic-de/cosmic-bg-${PV}
~cosmic-de/cosmic-comp-${PV}
~cosmic-de/cosmic-edit-${PV}
~cosmic-de/cosmic-files-${PV}
greeter? ( ~cosmic-de/cosmic-greeter-${PV} )
~cosmic-de/cosmic-icons-${PV}
~cosmic-de/cosmic-idle-${PV}
~cosmic-de/cosmic-launcher-${PV}
~cosmic-de/cosmic-notifications-${PV}
~cosmic-de/cosmic-osd-${PV}
~cosmic-de/cosmic-panel-${PV}
~cosmic-de/cosmic-player-${PV}
~cosmic-de/cosmic-randr-${PV}
~cosmic-de/cosmic-screenshot-${PV}
~cosmic-de/cosmic-session-${PV}[greeter=]
~cosmic-de/cosmic-settings-${PV}
~cosmic-de/cosmic-settings-daemon-${PV}
store? ( ~cosmic-de/cosmic-store-${PV} )
~cosmic-de/cosmic-term-${PV}
~cosmic-de/cosmic-workspaces-epoch-${PV}
~cosmic-de/pop-launcher-${PV}
~cosmic-de/pop-theme-meta-1.0.0_alpha6
~cosmic-de/xdg-desktop-portal-cosmic-${PV}
"
