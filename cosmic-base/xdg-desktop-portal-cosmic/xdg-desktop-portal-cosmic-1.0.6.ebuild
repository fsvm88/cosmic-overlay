# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

RUST_NEEDS_LLVM=1

inherit cosmic-de-r2 systemd

DESCRIPTION="Cosmic backend for xdg-desktop-portal"
HOMEPAGE="https://github.com/pop-os/xdg-desktop-portal-cosmic"

SRC_URI="https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${PN}-${PVR}.full.tar.zst"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

PATCHES=(
	"${FILESDIR}/xdg-desktop-portal-1.0.0_beta3-add-SystemdService-directive.patch"
)

RDEPEND+="
	>=media-libs/mesa-24.0.4
"

src_prepare() {
	cosmic-de-r2_src_prepare

	sed \
		-i 's|@libexecdir@/|/usr/libexec/|' \
		data/org.freedesktop.impl.portal.desktop.cosmic.service.in \
		data/dbus-1/org.freedesktop.impl.portal.desktop.cosmic.service.in \
		|| die "sed failed in src_prepare"
}

src_configure() {
	# Required for some crates to build properly due to build.rs scripts
	export VERGEN_GIT_COMMIT_DATE='Tue Feb 10 17:05:17 2026 +0100'
	export VERGEN_GIT_SHA=276af0b38c77bbb52fcb864ada151ed2eb93ae3a

	cosmic-de-r2_src_configure
}

src_install() {
	exeinto /usr/libexec
	doexe "$(cosmic-de-r2_target_dir)/$PN"

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
