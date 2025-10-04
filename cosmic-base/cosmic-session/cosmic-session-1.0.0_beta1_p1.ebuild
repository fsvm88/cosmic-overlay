# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de desktop systemd

DESCRIPTION="sessions manager for the COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-session"

MY_PV="epoch-1.0.0-beta.1.1"
SRC_URI="
	https://github.com/pop-os/${PN}/archive/refs/tags/${MY_PV}.tar.gz -> ${PN}-${PV}.tar.gz
	https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${P}-crates.tar.zst
	"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"
IUSE+=" accessibility +greeter cups"

RDEPEND+="
	~cosmic-base/cosmic-applets-${PV}
	~cosmic-base/cosmic-applibrary-${PV}
	~cosmic-base/cosmic-bg-${PV}
	~cosmic-base/cosmic-comp-${PV}
	greeter? ( ~cosmic-base/cosmic-greeter-${PV} )
	~cosmic-base/cosmic-icons-${PV}
	~cosmic-base/cosmic-idle-${PV}
	~cosmic-base/cosmic-launcher-${PV}
	~cosmic-base/cosmic-notifications-${PV}
	~cosmic-base/cosmic-osd-${PV}
	~cosmic-base/cosmic-panel-${PV}
	~cosmic-base/cosmic-randr-${PV}
	~cosmic-base/cosmic-screenshot-${PV}
	~cosmic-base/cosmic-settings-${PV}
	~cosmic-base/cosmic-settings-daemon-${PV}
	~cosmic-base/cosmic-wallpapers-${PV}
	~cosmic-base/cosmic-workspaces-epoch-${PV}
	~cosmic-base/xdg-desktop-portal-cosmic-${PV}
	~cosmic-base/pop-fonts-9999
	>=media-fonts/fira-mono-4.202
	>=media-fonts/fira-sans-4.202
	>=sys-power/switcheroo-control-2.6-r2
	>=x11-base/xwayland-23.2.6
	accessibility? ( >=app-accessibility/orca-46.2-r1 )
	cups? ( >=app-admin/system-config-printer-1.5.18-r2 )
"

src_prepare() {
	use elogind && eapply "${FILESDIR}/no_journald-systemctl.patch"
	cosmic-de_src_prepare

	# patch for dconf profile as done in justfile upstream
	# no more need for workaround in src_install
	# https://github.com/pop-os/cosmic-session/pull/95/files
	sed \
		-i "s|DCONF_PROFILE=cosmic|DCONF_PROFILE=/usr/share/dconf/profile/cosmic|" \
		data/start-cosmic
}

src_configure() {
	# This is required because this string is incorporated in the binary during the build process
	# Technically there's a fallback .unwrap_or_default() in the code,
	# but we should still keep this aligned to xdg-desktop-portal-cosmic
	export XDP_COSMIC="/usr/libexec/xdg-desktop-portal-cosmic"
	if use elogind; then
		# Features autostart enables XDG autostart support for non-systemd systems
		# Based on the original PR, this could be enabled without harm also for systemd systems,
		# because it does auto-detection, but since we already have a conditional for this, lets just add it
		# https://github.com/pop-os/cosmic-session/pull/109
		cosmic-de_src_configure --no-default-features --features autostart
	else
		cosmic-de_src_configure
	fi
}

src_install() {
	dobin "$(cosmic-de_target_dir)/$PN"

	dobin data/start-cosmic

	systemd_douserunit data/cosmic-session.target

	insinto /usr/share/wayland-sessions
	doins data/cosmic.desktop

	domenu data/cosmic-mimeapps.list

	# This install was copied from the cosmic-session debian package available from Pop!_OS
	# https://github.com/pop-os/cosmic-session/commit/c341953588098c1735f7984a13e64399b92d4313
	# https://github.com/pop-os/cosmic-session/commit/db1b12b7d764dd2d973933dbbb37ca276035c694
	# https://github.com/pop-os/cosmic-session/commit/153952c1ed2cb98772a84aa9b2c8729f6451c8ea
	insinto /usr/share/glib-2.0/schemas
	newins debian/cosmic-session.gsettings-override 50_cosmic-session.gschema.override

	insinto /usr/share/dconf/profile
	doins data/dconf/profile/cosmic
}
