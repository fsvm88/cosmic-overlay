# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

RUST_NEEDS_LLVM=1

inherit cosmic-live desktop systemd

DESCRIPTION="settings application for the COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-settings"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH=master

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS=""
IUSE+=" +networkmanager openvpn bluetooth"

RDEPEND+="
	bluetooth? ( >=net-wireless/bluez-5.86 )
	~cosmic-base/cosmic-icons-${PV}
	~cosmic-base/cosmic-randr-${PV}
	>=app-text/iso-codes-4.16.0
	>=dev-libs/expat-2.5.0
	>=dev-util/desktop-file-utils-0.27
	>=media-fonts/fira-mono-4.202
	>=media-fonts/fira-sans-4.202
	>=media-libs/fontconfig-2.14.2-r3
	>=media-libs/freetype-2.13.2
	networkmanager? (
		>=net-misc/networkmanager-1.46.0
		>=gnome-extra/nm-applet-1.36.0
		openvpn? ( >=net-vpn/networkmanager-openvpn-1.10.2 )
	)
	>=sys-apps/accountsservice-23.13.9
	>=sys-devel/gettext-0.22.4
	>=x11-misc/xkeyboard-config-2.41
"

src_install() {
	dobin "$(cosmic-common_target_dir)/$PN"

	domenu target/xdgen/*.desktop

	cosmic-common_install_metainfo resources/com.system76.CosmicSettings.metainfo.xml

	insinto /usr/share/cosmic
	doins -r resources/default_schema/*

	insinto /usr/share/icons/hicolor
	doins -r resources/icons/*

	insinto /usr/share/polkit-1/rules.d/
	doins resources/polkit-1/rules.d/cosmic-settings.rules

	insinto /usr/share/polkit-1/actions
	doins resources/polkit-1/actions/com.system76.CosmicSettings.Users.policy
}

pkg_postinst() {
	if use bluetooth; then
		elog "In order for bluetooth to function, you must start and enable"
		elog "bluetooth:"
		if systemd_is_booted; then
			elog "  systemctl enable --now bluetooth"
		elif [[ -d /run/openrc ]]; then
			elog "  rc-service bluetooth start"
			elog "  rc-update add bluetooth default"
		else
			elog "  Please use your init system's standard tools to start"
			elog "  and enable the 'bluetooth' service."
		fi
	fi
}
