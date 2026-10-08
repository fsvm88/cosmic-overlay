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
IUSE="+fonts +gnome-keyring +greeter +monitor store +viewer"

RDEPEND="
=cosmic-base/cosmic-applets-$(ver_cut 1-2)*
=cosmic-base/cosmic-app-library-$(ver_cut 1-2)*
=cosmic-base/cosmic-bg-$(ver_cut 1-2)*
=cosmic-base/cosmic-comp-$(ver_cut 1-2)*
=cosmic-base/cosmic-edit-$(ver_cut 1-2)*
=cosmic-base/cosmic-files-$(ver_cut 1-2)*
greeter? ( =cosmic-base/cosmic-greeter-$(ver_cut 1-2)* )
=cosmic-base/cosmic-icons-$(ver_cut 1-2)*
=cosmic-base/cosmic-idle-$(ver_cut 1-2)*
=cosmic-base/cosmic-initial-setup-$(ver_cut 1-2)*
=cosmic-base/cosmic-launcher-$(ver_cut 1-2)*
monitor? ( =cosmic-base/cosmic-monitor-$(ver_cut 1-2)* )
=cosmic-base/cosmic-notifications-$(ver_cut 1-2)*
=cosmic-base/cosmic-osd-$(ver_cut 1-2)*
=cosmic-base/cosmic-panel-$(ver_cut 1-2)*
=cosmic-base/cosmic-player-$(ver_cut 1-2)*
=cosmic-base/cosmic-randr-$(ver_cut 1-2)*
=cosmic-base/cosmic-screenshot-$(ver_cut 1-2)*
=cosmic-base/cosmic-session-$(ver_cut 1-2)*[greeter=]
=cosmic-base/cosmic-settings-$(ver_cut 1-2)*
=cosmic-base/cosmic-settings-daemon-$(ver_cut 1-2)*
=cosmic-base/cosmic-sound-theme-$(ver_cut 1-2)*
store? ( =cosmic-base/cosmic-store-$(ver_cut 1-2)* )
=cosmic-base/cosmic-term-$(ver_cut 1-2)*
viewer? ( =cosmic-base/cosmic-viewer-$(ver_cut 1-2)* )
=cosmic-base/cosmic-workspaces-epoch-$(ver_cut 1-2)*
=cosmic-base/pop-launcher-$(ver_cut 1-2)*
~cosmic-base/pop-theme-meta-9999
=cosmic-base/xdg-desktop-portal-cosmic-$(ver_cut 1-2)*
fonts? (
	media-fonts/open-sans:0
	media-fonts/noto:0
)
gnome-keyring? ( >=gnome-base/gnome-keyring-46.2 )
"
