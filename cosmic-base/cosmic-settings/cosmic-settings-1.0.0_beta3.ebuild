# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

LLVM_COMPAT=({18..20})
LLVM_OPTIONAL=1

inherit cosmic-de desktop llvm-r1

DESCRIPTION="settings application for the COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-settings"

MY_PV="epoch-1.0.0-beta.3"

SRC_URI="
	https://github.com/pop-os/${PN}/archive/refs/tags/${MY_PV}.tar.gz -> ${PN}-${PV}.tar.gz
	https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${P}-crates.tar.zst
	"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"
IUSE+=" +networkmanager openvpn"

REQUIRED_USE+=" ${LLVM_REQUIRED_USE}"

RDEPEND+="
	~cosmic-base/cosmic-icons-${PV}
	~cosmic-base/cosmic-randr-${PV}
	>=app-text/iso-codes-4.16.0
	>=dev-libs/expat-2.5.0
	>=dev-util/desktop-file-utils-0.27
	>=gnome-extra/nm-applet-1.36.0
	>=media-fonts/fira-mono-4.202
	>=media-fonts/fira-sans-4.202
	>=media-libs/fontconfig-2.14.2-r3
	>=media-libs/freetype-2.13.2
	networkmanager? (
		>=net-misc/networkmanager-1.46.0
		openvpn? ( >=net-vpn/networkmanager-openvpn-1.10.2 )
	)
	>=sys-apps/accountsservice-23.13.9
	>=sys-devel/gettext-0.22.4
	>=x11-misc/xkeyboard-config-2.41
	$(llvm_gen_dep '
		llvm-core/clang:${LLVM_SLOT}
		llvm-core/llvm:${LLVM_SLOT}
	')
"

pkg_setup() {
	rust_pkg_setup
	llvm-r1_pkg_setup
}

src_install() {
	dobin "$(cosmic-de_target_dir)/$PN"

	domenu resources/applications/*.desktop

	cosmic-de_install_metainfo resources/com.system76.CosmicSettings.metainfo.xml

	insinto /usr/share/cosmic
	doins -r resources/default_schema/*

	insinto /usr/share/icons/hicolor
	doins -r resources/icons/*

	insinto /usr/share/polkit-1/rules.d/
	doins resources/polkit-1/rules.d/cosmic-settings.rules

	insinto /usr/share/polkit-1/actions
	doins resources/polkit-1/actions/com.system76.CosmicSettings.Users.policy
}
