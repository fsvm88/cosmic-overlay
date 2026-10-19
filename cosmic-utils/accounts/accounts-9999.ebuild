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
	local appid="dev.edfloreshz.Accounts"

	# Main executables
	dobin "$(cosmic-common_target_dir)/accounts-daemon"
	dobin "$(cosmic-common_target_dir)/accounts_ui"

	# D-Bus activation wrappers
	dobin crates/ui/data/accounts-ui-daemon
	dobin crates/ui/data/accounts-consent-prompt

	# systemd user service
	systemd_douserunit crates/ui/data/cosmic-accounts.service

	# D-Bus activation files supplied by upstream
	insinto /usr/share/dbus-1/services
	doins crates/ui/data/dev.edfloreshz.Accounts.service
	doins crates/ui/data/dev.edfloreshz.Accounts.ConsentPrompt.service

	# OAuth provider configurations
	insinto /usr/share/accounts/providers
	doins crates/ui/data/providers/*.toml

	# Desktop entry
	newmenu crates/ui/resources/app.desktop "${appid}.desktop"

	# AppStream metadata
	insinto /usr/share/metainfo
	newins crates/ui/resources/app.metainfo.xml "${appid}.metainfo.xml"

	# Application icon
	newicon -s scalable \
		crates/ui/resources/icons/hicolor/scalable/apps/icon.svg \
		"${appid}.svg"

	# Documentation
	einstalldocs
}

pkg_postinst() {
	cosmic-live_pkg_postinst

	elog "OAuth provider manifests are installed in /usr/share/accounts/providers/."
	elog ""
	elog "The user service can be enabled with:"
	elog "  systemctl --user enable --now cosmic-accounts.service"
	elog ""
	elog "D-Bus activation is provided by the installed service files."
}
