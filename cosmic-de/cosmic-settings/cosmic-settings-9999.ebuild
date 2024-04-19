
# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

# Auto-Generated by cargo-ebuild 0.5.4

EAPI=8

inherit cosmic-de desktop

DESCRIPTION="settings application for the COSMIC DE"
HOMEPAGE="https://github.com/pop-os/$PN"

if [ "${PV}" == "9999" ]; then
	EGIT_REPO_URI="${HOMEPAGE}"
else
	# TODO this is not really working atm
	SRC_URI="https://github.com/pop-os/${PN}/archive/refs/tags/${MY_PV}.tar.gz -> ${P}.tar.gz
				$(cargo_crate_uris)
"
fi

# License set may be more restrictive as OR is not respected
# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

# As per https://raw.githubusercontent.com/pop-os/cosmic-settings/master/debian/control
DEPEND="
${DEPEND}
>=dev-libs/wayland-1.20
app-text/iso-codes
cosmic-de/cosmic-randr
dev-libs/expat
dev-libs/libinput
media-libs/fontconfig
media-libs/freetype
sys-apps/accountsservice
sys-devel/gettext
virtual/libudev
x11-misc/xkeyboard-config
"
BDEPEND="${BDEPEND}"
RDEPEND="
${RDEPEND}
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
