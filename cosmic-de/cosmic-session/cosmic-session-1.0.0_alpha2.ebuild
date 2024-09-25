# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

COSMIC_GIT_UNPACK=1
inherit cosmic-de systemd

DESCRIPTION="sessions manager for the COSMIC DE"
HOMEPAGE="https://github.com/pop-os/$PN"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_COMMIT="epoch-1.0.0-alpha.2"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

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
	=cosmic-de/cosmic-wallpapers-${PV}
	=cosmic-de/cosmic-workspaces-epoch-${PV}
	=cosmic-de/xdg-desktop-portal-cosmic-${PV}
	=cosmic-de/pop-fonts-9999
	>=media-fonts/fira-mono-4.202
	>=media-fonts/fira-sans-4.202
	>=sys-power/switcheroo-control-2.6-r2
	>=x11-base/xwayland-23.2.6
"

src_prepare() {
	use elogind && eapply "${FILESDIR}/no_journald-systemctl.patch"
	cosmic-de_src_prepare
}

src_configure() {
	# This is required because this string is incorporated in the binary during the build process
	# Technically there's a fallback .unwrap_or_default() in the code,
	# but we should still keep this aligned to xdg-desktop-portal-cosmic
	export XDP_COSMIC="/usr/libexec/xdg-desktop-portal-cosmic"
	if use elogind; then
		cosmic-de_src_configure --no-default-features
	else
		cosmic-de_src_configure
	fi
}

src_install() {
	dobin "target/$profile_name/$PN"

	dobin data/start-cosmic

	systemd_douserunit data/cosmic-session.target

	insinto /usr/share/wayland-sessions
	doins data/cosmic.desktop

	insinto /usr/share/applications
	doins data/cosmic-mimeapps.list

	# This install was copied from the cosmic-session debian package available from Pop!_OS
	# https://github.com/pop-os/cosmic-session/commit/c341953588098c1735f7984a13e64399b92d4313
	# https://github.com/pop-os/cosmic-session/commit/db1b12b7d764dd2d973933dbbb37ca276035c694
	# https://github.com/pop-os/cosmic-session/commit/153952c1ed2cb98772a84aa9b2c8729f6451c8ea
	insinto /usr/share/glib-2.0/schemas
	newins debian/cosmic-session.gsettings-override 50_cosmic-session.gschema.override
}
