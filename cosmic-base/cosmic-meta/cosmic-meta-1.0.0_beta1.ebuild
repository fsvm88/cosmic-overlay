# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

DESCRIPTION="Meta package for cosmic-base"
HOMEPAGE="https://github.com/pop-os/cosmic-epoch"

# Updated ebuilds at 2eadc4e 20.04.2024
# This is a meta package, trying to include most of the licenses used by sub-packages, but no guarantee
# Not sure how/if this should be handled better
LICENSE="CC-BY-SA-4.0 GPL-3 GPL-3+ MPL-2.0"

SLOT="0"
KEYWORDS="~amd64"
IUSE="+fonts +gnome-keyring +greeter store"

RDEPEND="
~cosmic-base/cosmic-applets-${PV}
~cosmic-base/cosmic-applibrary-${PV}
~cosmic-base/cosmic-bg-${PV}
~cosmic-base/cosmic-comp-${PV}
~cosmic-base/cosmic-edit-${PV}
~cosmic-base/cosmic-files-${PV}
greeter? ( ~cosmic-base/cosmic-greeter-${PV} )
~cosmic-base/cosmic-icons-${PV}
~cosmic-base/cosmic-idle-${PV}
~cosmic-base/cosmic-initial-setup-${PV}
~cosmic-base/cosmic-launcher-${PV}
~cosmic-base/cosmic-notifications-${PV}
~cosmic-base/cosmic-osd-${PV}
~cosmic-base/cosmic-panel-${PV}
~cosmic-base/cosmic-player-${PV}
~cosmic-base/cosmic-randr-${PV}
~cosmic-base/cosmic-screenshot-${PV}
~cosmic-base/cosmic-session-${PV}[greeter=]
~cosmic-base/cosmic-settings-${PV}
~cosmic-base/cosmic-settings-daemon-${PV}
store? ( ~cosmic-base/cosmic-store-${PV} )
~cosmic-base/cosmic-term-${PV}
~cosmic-base/cosmic-workspaces-epoch-${PV}
~cosmic-base/pop-launcher-9999
~cosmic-base/pop-theme-meta-9999
~cosmic-base/xdg-desktop-portal-cosmic-${PV}
fonts? (
	media-fonts/open-sans:0
	media-fonts/noto:0
)
gnome-keyring? ( >=gnome-base/gnome-keyring-46.2 )
"
