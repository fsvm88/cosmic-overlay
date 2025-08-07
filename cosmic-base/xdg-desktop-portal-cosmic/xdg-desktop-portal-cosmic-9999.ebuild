# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

LLVM_COMPAT=({18..20})
LLVM_OPTIONAL=1
inherit cosmic-de llvm-r1

DESCRIPTION="Cosmic backend for xdg-desktop-portal"
HOMEPAGE="https://github.com/pop-os/xdg-desktop-portal-cosmic"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH=master

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS=""

REQUIRED_USE+=" ${LLVM_REQUIRED_USE}"

RDEPEND+="
	>=media-libs/mesa-24.0.4
	>=media-video/pipewire-1.0.3
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
	exeinto /usr/libexec
	doexe "$(cosmic-de_target_dir)/$PN"

	insinto /usr/share/dbus-1/services
	doins data/org.freedesktop.impl.portal.desktop.cosmic.service

	insinto /usr/share/xdg-desktop-portal/portals
	doins data/cosmic.portal

	insinto /usr/share/xdg-desktop-portal
	doins data/cosmic-portals.conf

	insinto /usr/share/icons/hicolor
	doins -r data/icons/*
}
