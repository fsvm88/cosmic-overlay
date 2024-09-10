# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

COSMIC_GIT_UNPACK=1
inherit cosmic-de

DESCRIPTION="settings daemon for the COSMIC DE"
HOMEPAGE="https://github.com/pop-os/$PN"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_COMMIT="epoch-1.0.0-alpha.1"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	${RDEPEND}
	>=app-misc/geoclue-2.7.1
	>=media-sound/playerctl-2.3.1
	>=sys-power/acpid-2.0.34-r1
"

src_install() {
	dobin "target/$profile_name/$PN"

	insinto /usr/share/cosmic/com.system76.CosmicSettings.Shortcuts/v1/
	newins data/system_actions.ron system_actions

	insinto /usr/share/polkit-1/rules.d/
	doins data/polkit-1/rules.d/cosmic-settings-daemon.rules
}
