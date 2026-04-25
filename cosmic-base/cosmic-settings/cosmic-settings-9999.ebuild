# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

RUST_NEEDS_LLVM=1

inherit cosmic-live desktop

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

src_configure() {
	local myfeatures=(
		"a11y"
		"cosmic-comp-config"
		"page-accessibility"
		"page-about"
		$(usev bluetooth "page-bluetooth")
		"page-date"
		"page-default-apps"
		"page-display"
		"page-input"
		"page-legacy-applications"
		"page-networking"
		"page-power"
		"page-region"
		"page-sound"
		"page-users"
		"page-window-management"
		"page-workspaces"
		"xdg-portal"
		"wayland"
		"single-instance"
		"wgpu"
	)

	cosmic-de-r2_src_configure --no-default-features
}

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
		if use systemd; then
			elog "  systemctl enable --now bluetooth"
		else
			elog "  rc-service bluetooth start"
			elog "  rc-update add bluetooth default"
		fi
	fi
}
