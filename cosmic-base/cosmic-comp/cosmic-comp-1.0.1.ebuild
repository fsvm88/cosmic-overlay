# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de

DESCRIPTION="compositor for COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-comp"

MY_PV="epoch-1.0.1"

SRC_URI="
	https://github.com/pop-os/${PN}/archive/refs/tags/${MY_PV}.tar.gz -> ${PN}-${PV}.tar.gz
	https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${P}-crates.tar.zst
	"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND+="
	>=media-libs/fontconfig-2.14.2-r3
	>=media-libs/mesa-24.0.4
	>=sys-auth/seatd-0.8.0
	>=x11-libs/libxcb-1.16.1
	>=x11-libs/pixman-0.43.4
	media-libs/libdisplay-info:0/3
"

src_configure() {
	if use elogind; then
		cosmic-de_src_configure --no-default-features
	else
		cosmic-de_src_configure
	fi
}

src_install() {
	dobin "$(cosmic-de_target_dir)/$PN"

	# Default keybindings
	insinto /usr/share/cosmic/com.system76.CosmicSettings.Shortcuts/v1
	newins data/keybindings.ron defaults

	# Tiling exceptions
	insinto /usr/share/cosmic/com.system76.CosmicSettings.WindowRules/v1
	newins data/tiling-exceptions.ron tiling_exception_defaults
}
