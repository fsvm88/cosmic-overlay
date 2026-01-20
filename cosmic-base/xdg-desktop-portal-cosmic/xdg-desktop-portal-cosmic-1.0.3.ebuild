# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

RUST_NEEDS_LLVM=1

inherit cosmic-de systemd

DESCRIPTION="Cosmic backend for xdg-desktop-portal"
HOMEPAGE="https://github.com/pop-os/xdg-desktop-portal-cosmic"

MY_PV="epoch-1.0.3"

SRC_URI="
	https://github.com/pop-os/${PN}/archive/refs/tags/${MY_PV}.tar.gz -> ${PN}-${PV}.tar.gz
	https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${P}-crates.tar.zst
	"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

# PATCHES commented out during bump due to patch failure - needs manual review
PATCHES=(
    "${FILESDIR}/xdg-desktop-portal-1.0.0_beta3-add-SystemdService-directive.patch"
)

RDEPEND+="
	>=media-libs/mesa-24.0.4
	>=media-video/pipewire-1.0.3
"

src_prepare() {
	cosmic-de_src_prepare

	sed \
		-i 's|@libexecdir@/|/usr/libexec/|' \
		data/org.freedesktop.impl.portal.desktop.cosmic.service.in \
		data/dbus-1/org.freedesktop.impl.portal.desktop.cosmic.service.in \
		|| die "sed failed in src_prepare"
}

src_configure() {
	# Required for some crates to build properly due to build.rs scripts
	export VERGEN_GIT_COMMIT_DATE='Fri Jan 16 16:08:41 2026 -0700'
	export VERGEN_GIT_SHA=e80eb7f11247371efd06e373d891815cd6a8acf1

	cosmic-de_src_configure
}

src_install() {
	exeinto /usr/libexec
	doexe "$(cosmic-de_target_dir)/$PN"

	systemd_newuserunit data/org.freedesktop.impl.portal.desktop.cosmic.service.in \
			xdg-desktop-portal-cosmic.service

	insinto /usr/share/dbus-1/services
	newins data/dbus-1/org.freedesktop.impl.portal.desktop.cosmic.service.in \
			org.freedesktop.impl.portal.desktop.cosmic.service

	insinto /usr/share/xdg-desktop-portal/portals
	doins data/cosmic.portal

	insinto /usr/share/xdg-desktop-portal
	doins data/cosmic-portals.conf

	insinto /usr/share/icons/hicolor
	doins -r data/icons/*
}
