# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de-r2

DESCRIPTION="settings daemon for the COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-settings-daemon"

SRC_URI="https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${PN}-${PVR}.full.tar.zst"
# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"
IUSE+=" mpris"

RDEPEND+="
	media-sound/alsa-utils
	mpris? ( >=media-sound/playerctl-2.3.1 )
	>=sys-power/acpid-2.0.34-r1
	>=x11-themes/adw-gtk3-6.2
	~cosmic-base/pop-theme-meta-9999
"

src_install() {
	dobin "$(cosmic-common_target_dir)/$PN"

	insinto /usr/share/cosmic/com.system76.CosmicSettings.Shortcuts/v1/
	newins data/system_actions.ron system_actions

	insinto /usr/share/polkit-1/rules.d/
	doins data/polkit-1/rules.d/cosmic-settings-daemon.rules
}
