# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de desktop

DESCRIPTION="initial setup program for COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-initial-setup"

MY_PV="epoch-1.0.0"

SRC_URI="
	https://github.com/pop-os/${PN}/archive/refs/tags/${MY_PV}.tar.gz -> ${PN}-${PV}.tar.gz
	https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${P}-crates.tar.zst
	"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND+="
	acct-user/cosmic-initial-setup
	~cosmic-base/pop-appstream-data-9999
	~cosmic-base/cosmic-icons-${PV}
"

src_install() {
	dobin "$(cosmic-de_target_dir)/$PN"

	domenu res/*.desktop

	insinto /etc/xdg/autostart
	newins res/com.system76.CosmicInitialSetup.Autostart.desktop com.system76.CosmicInitialSetup.desktop

	insinto /usr/share/icons/hicolor/scalable/apps/
	newins res/icon.svg com.system76.CosmicInitialSetup.svg

	insinto /usr/share/polkit-1/rules.d
	doins res/20-cosmic-initial-setup.rules

	insinto /usr/share/cosmic-layouts
	doins -r res/layouts/*

	insinto /usr/share/cosmic-themes
	doins res/themes/*
}
