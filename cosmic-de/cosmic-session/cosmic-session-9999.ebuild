# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de systemd

DESCRIPTION="sessions manager for the COSMIC DE"
HOMEPAGE="https://github.com/pop-os/$PN"

if [ "${PV}" == "9999" ]; then
	EGIT_REPO_URI="${HOMEPAGE}"
	EGIT_COMMIT=577a181
else
	# TODO this is not really working atm
	SRC_URI="https://github.com/pop-os/${PN}/archive/refs/tags/${MY_PV}.tar.gz -> ${P}.tar.gz
				$(cargo_crate_uris)
"
fi

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

# As per https://raw.githubusercontent.com/pop-os/cosmic-session/master/debian/control
RDEPEND="
		${RDEPEND}
		=cosmic-de/cosmic-applets-${PV}
		=cosmic-de/cosmic-applibrary-${PV}
		=cosmic-de/cosmic-bg-${PV}
		=cosmic-de/cosmic-comp-${PV}
		=cosmic-de/cosmic-greeter-${PV}
		=cosmic-de/cosmic-icons-${PV}
		=cosmic-de/cosmic-launcher-${PV}
		=cosmic-de/cosmic-notifications-${PV}
		=cosmic-de/cosmic-osd-${PV}
		=cosmic-de/cosmic-panel-${PV}
		=cosmic-de/cosmic-randr-${PV}
		=cosmic-de/cosmic-screenshot-${PV}
		=cosmic-de/cosmic-settings-${PV}
		=cosmic-de/cosmic-settings-daemon-${PV}
		=cosmic-de/cosmic-workspaces-epoch-${PV}
		=cosmic-de/xdg-desktop-portal-cosmic-${PV}
		=cosmic-de/pop-fonts-${PV}
		>=media-fonts/fira-mono-4.202
		>=media-fonts/fira-sans-4.202
		>=x11-base/xwayland-23.2.6
"

src_configure() {
	# This is required because this string is incorporated in the binary during the build process
	# Technically there's a fallback .unwrap_or_default() in the code,
	# but we should still keep this aligned to xdg-desktop-portal-cosmic
	export XDP_COSMIC="/usr/libexec/xdg-desktop-portal-cosmic"
	cosmic-de_src_configure
}

src_install() {
	dobin "target/$profile_name/$PN"

	dobin data/start-cosmic

	systemd_douserunit data/cosmic-session.target

	insinto /usr/share/wayland-sessions
	doins data/cosmic.desktop

	insinto /usr/share/applications
	doinst data/cosmic-mimeapps.list
}
