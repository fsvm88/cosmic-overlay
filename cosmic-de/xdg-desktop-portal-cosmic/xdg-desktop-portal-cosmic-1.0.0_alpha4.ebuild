# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

COSMIC_GIT_UNPACK=1
inherit cosmic-de

DESCRIPTION="Cosmic backend for xdg-desktop-portal"
HOMEPAGE="https://github.com/pop-os/xdg-desktop-portal-cosmic"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_COMMIT="epoch-1.0.0-alpha.4"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

# As per https://raw.githubusercontent.com/pop-os/xdg-desktop-portal-cosmic/master/debian/control
DEPEND="
	${DEPEND}
	>=media-libs/mesa-24.0.4
	>=media-video/pipewire-1.0.3
	>=sys-devel/clang-18
"

src_install() {
	exeinto /usr/libexec
	doexe "target/$profile_name/$PN"

	insinto /usr/share/dbus-1/services
	doins data/org.freedesktop.impl.portal.desktop.cosmic.service

	insinto /usr/share/xdg-desktop-portal/portals
	doins data/cosmic.portal

	insinto /usr/share/xdg-desktop-portal
	doins data/cosmic-portals.conf

	insinto /usr/share/icons/hicolor
	doins -r data/icons/*
}
