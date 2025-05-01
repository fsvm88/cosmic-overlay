# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

LLVM_COMPAT=({18..19})
LLVM_OPTIONAL=1

inherit cosmic-de llvm-r1

DESCRIPTION="Cosmic backend for xdg-desktop-portal"
HOMEPAGE="https://github.com/pop-os/xdg-desktop-portal-cosmic"

MY_PV="epoch-1.0.0-alpha.7"

SRC_URI="
	https://github.com/pop-os/${PN}/archive/refs/tags/${MY_PV}.tar.gz -> ${PN}-${PV}.tar.gz
	https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${P}-crates.tar.zst
	"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

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

src_configure() {
	# Required for some crates to build properly due to build.rs scripts
	export VERGEN_GIT_COMMIT_DATE='Tue Apr 8 08:46:49 2025 -0600'
	export VERGEN_GIT_SHA=b655a8ef068390e20740d48f267e9e23b173c198

	cosmic-de_src_configure
}

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
