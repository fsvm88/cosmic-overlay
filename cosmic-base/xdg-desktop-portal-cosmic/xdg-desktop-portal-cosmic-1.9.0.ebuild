# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

RUST_NEEDS_LLVM=1

inherit cosmic-de-r2 systemd

DESCRIPTION="Cosmic backend for xdg-desktop-portal"
HOMEPAGE="https://github.com/pop-os/xdg-desktop-portal-cosmic"

SRC_URI="https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${PN}-${PV}.full.tar.zst"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

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
	export VERGEN_GIT_COMMIT_DATE='Tue Sep 15 21:52:46 2026 +0200'
	export VERGEN_GIT_SHA=2f41161176368840c67e2de9b8a24786accb100c

	local myfeatures=(
		$(usev systemd)
	)

	cosmic-de-r2_src_configure --no-default-features
}

src_install() {
	exeinto /usr/libexec
	doexe "$(cosmic-common_target_dir)/$PN"

	systemd_newuserunit data/org.freedesktop.impl.portal.desktop.cosmic.service.in \
			org.freedesktop.impl.portal.desktop.cosmic.service

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
