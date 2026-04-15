# Copyright 2025 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-live desktop systemd

DESCRIPTION="Online account management service for the COSMIC desktop"
HOMEPAGE="https://github.com/cosmic-utils/accounts"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH=main

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND+="
	sys-apps/dbus
"

DEPEND="${RDEPEND}"

BDEPEND="
	virtual/pkgconfig
"

src_configure() {
	cosmic-live_src_configure --all
}

src_install() {
	export APPID="dev.edfloreshz.Accounts"

	# Install daemon
	dobin "$(cosmic-common_target_dir)/accounts-daemon"

	# Install GUI application
	dobin "$(cosmic-common_target_dir)/accounts-ui"

	# Install systemd user service
	systemd_douserunit accounts-daemon/data/cosmic-accounts.service

	# Install D-Bus service activation file
	# Create the D-Bus service file for proper D-Bus activation
	insinto /usr/share/dbus-1/services
	cat > "${T}"/${APPID}.service <<-EOF || die
		[D-BUS Service]
		Name=${APPID}
		Exec=/usr/bin/accounts-daemon
		SystemdService=cosmic-accounts.service
	EOF
	doins "${T}"/${APPID}.service

	# Install provider configurations
	insinto /etc/accounts/providers
	doins accounts-daemon/data/providers/*.toml

	# Install desktop file with proper name
	newmenu accounts-ui/resources/app.desktop ${APPID}.desktop

	# Install metainfo with proper name
	insinto /usr/share/metainfo
	newins accounts-ui/resources/app.metainfo.xml ${APPID}.metainfo.xml
	# Install icon with proper name matching the desktop file
	newicon -s scalable accounts-ui/resources/icons/hicolor/scalable/apps/icon.svg ${APPID}.svg

	# Documentation
	einstalldocs
}

pkg_postinst() {
	cosmic-live_pkg_postinst

	elog "To use the accounts daemon, you may need to configure OAuth2 credentials"
	elog "in the provider configuration files at /etc/accounts/providers/"
	elog ""
	elog "The daemon can be started with:"
	elog "  systemctl --user enable --now cosmic-accounts.service"
	elog ""
	elog "Or it will be launched on-demand via D-Bus activation."
}
