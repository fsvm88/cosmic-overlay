# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de

DESCRIPTION="compositor for COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-comp"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH=master

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS=""

# As per https://raw.githubusercontent.com/pop-os/cosmic-comp/master/debian/control
DEPEND="
	${DEPEND}
	>=media-libs/fontconfig-2.14.2-r3
	>=media-libs/mesa-24.0.4
	>=sys-auth/seatd-0.8.0
	>=x11-libs/libxcb-1.16.1
	>=x11-libs/pixman-0.43.4
	media-libs/libdisplay-info:0
"

src_configure() {
	if use elogind; then
		cosmic-de_src_configure --no-default-features
	else
		cosmic-de_src_configure
	fi
}

src_install() {
	dobin "target/$profile_name/$PN"

	# Default keybindings
	insinto /usr/share/cosmic/com.system76.CosmicSettings.Shortcuts/v1
	newins data/keybindings.ron defaults

	# Tiling exceptions
	insinto /usr/share/cosmic/com.system76.CosmicSettings.WindowRules/v1
	newins data/tiling-exceptions.ron tiling_exception_defaults
}
