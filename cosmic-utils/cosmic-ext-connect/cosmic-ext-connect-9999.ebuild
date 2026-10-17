# Copyright 2026 Rosen Aleksandrov
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-live desktop optfeature systemd

DESCRIPTION="Native KDE Connect implementation (service + panel applet) for the COSMIC desktop"
HOMEPAGE="https://github.com/cosmic-utils/kdeconnect"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH=master

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND+="
	dev-libs/wayland
	media-libs/libpulse
	sys-apps/dbus
	sys-apps/xdg-desktop-portal
	x11-libs/libxkbcommon
	!kde-misc/kdeconnect
"

DEPEND="${RDEPEND}"

BDEPEND="
	virtual/pkgconfig
"

src_configure() {
	cosmic-live_src_configure --all
}

src_install() {
	export APPID="io.github.hepp3n.kdeconnect"

	# Background service (D-Bus / systemd / XDG autostart) and applet binaries
	dobin "$(cosmic-common_target_dir)/kdeconnect-service"
	dobin "$(cosmic-common_target_dir)/cosmic-ext-connect-applet"
	dobin "$(cosmic-common_target_dir)/cosmic-ext-connect-settings"
	dobin "$(cosmic-common_target_dir)/cosmic-ext-connect-sms"

	# Systemd user service: upstream hardcodes %h/.local/bin
	sed -e 's|%h/\.local/bin/kdeconnect-service|/usr/bin/kdeconnect-service|' \
		kdeconnect-service/kdeconnect.service > "${T}"/kdeconnect.service || die
	systemd_douserunit "${T}"/kdeconnect.service

	# D-Bus service activation file (upstream writes it with a $HOME prefix),
	# handing activation over to the systemd user unit
	insinto /usr/share/dbus-1/services
	cat > "${T}"/${APPID}.service <<-EOF || die
		[D-BUS Service]
		Name=${APPID}
		Exec=/usr/bin/kdeconnect-service
		SystemdService=kdeconnect.service
	EOF
	doins "${T}"/${APPID}.service

	# Desktop entries: applet, settings, SMS
	domenu resources/${APPID}.desktop
	domenu resources/${APPID}.settings.desktop
	domenu resources/${APPID}.sms.desktop

	# Metainfo
	insinto /usr/share/metainfo
	doins resources/${APPID}.metainfo.xml

	# Icon (already named after the application ID)
	doicon -s scalable resources/${APPID}.svg

	# Documentation
	einstalldocs
}

pkg_postinst() {
	cosmic-live_pkg_postinst

	elog "This package conflicts with the official KDE Connect (kde-misc/kdeconnect):"
	elog "both use TCP/UDP port 1716, so only one of them can be installed."
	elog ""
	elog "The service is started on demand via D-Bus activation through the"
	elog "systemd user unit kdeconnect.service. To start it at every login:"
	elog "  systemctl --user enable --now kdeconnect.service"
	elog "Logs are available with: journalctl --user -u kdeconnect.service"
	elog ""
	elog "To add the applet: COSMIC Settings -> Desktop -> Panel ->"
	elog "Configure Panel Applets -> KDE Connect (you may need to log out and in)."
	elog ""
	elog "Open the TCP and UDP port range 1714-1764 in your firewall to allow"
	elog "devices to discover and connect to this machine."

	optfeature "SFTP / Browse Device plugin" net-fs/sshfs
}
