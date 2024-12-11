# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

COSMIC_GIT_UNPACK=1
inherit cosmic-de desktop

DESCRIPTION="settings application for the COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-settings"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_COMMIT="epoch-1.0.0-alpha.4"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

# As per https://raw.githubusercontent.com/pop-os/cosmic-settings/master/debian/control
BDEPEND="
	${BDEPEND}
	>=dev-libs/expat-2.5.0
	>=media-libs/fontconfig-2.14.2-r3
	>=media-libs/freetype-2.13.2
	>=llvm-core/clang-18
"
RDEPEND="
	${RDEPEND}
	~cosmic-de/cosmic-icons-${PV}
	~cosmic-de/cosmic-randr-${PV}
	>=app-text/iso-codes-4.16.0
	>=media-fonts/fira-mono-4.202
	>=media-fonts/fira-sans-4.202
	>=net-misc/networkmanager-1.46.0
	>=net-vpn/networkmanager-openvpn-1.10.2
	>=sys-apps/accountsservice-23.13.9
	>=sys-devel/gettext-0.22.4
	>=x11-misc/xkeyboard-config-2.41
"

src_install() {
	dobin "target/$profile_name/$PN"

	domenu resources/*.desktop

	cosmic-de_install_metainfo resources/com.system76.CosmicSettings.metainfo.xml

	insinto /usr/share/cosmic
	doins -r resources/default_schema/*

	insinto /usr/share/icons/hicolor
	doins -r resources/icons/*

	insinto /usr/share/polkit-1/rules.d/
	doins resources/polkit-1/rules.d/cosmic-settings.rules
}
