# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de

DESCRIPTION="settings daemon for the COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-settings-daemon"
# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS=""

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH=master

IUSE+=" mpris"

# app-misc/geoclue was dropped thanks to https://github.com/pop-os/cosmic-settings-daemon/commit/f609f7d342bf5fb87ecc3779b8173d3bcd013417
RDEPEND+="
	media-sound/alsa-utils
	mpris? ( >=media-sound/playerctl-2.3.1 )
	>=sys-power/acpid-2.0.34-r1
	>=x11-themes/adw-gtk3-6.2
	~cosmic-base/pop-gtk-theme-${PV}
"

src_install() {
	dobin "target/$profile_name/$PN"

	insinto /usr/share/cosmic/com.system76.CosmicSettings.Shortcuts/v1/
	newins data/system_actions.ron system_actions

	insinto /usr/share/polkit-1/rules.d/
	doins data/polkit-1/rules.d/cosmic-settings-daemon.rules
}
