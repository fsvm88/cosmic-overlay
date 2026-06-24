# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-live desktop

DESCRIPTION="system monitor for COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-monitor"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH=master

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS=""

src_install() {
	dobin "$(cosmic-common_target_dir)/$PN"

	domenu target/xdgen/com.system76.CosmicMonitor.desktop

	cosmic-common_install_metainfo target/xdgen/com.system76.CosmicMonitor.metainfo.xml

	insinto /usr/share/icons/hicolor
	doins -r res/icons/hicolor/*
}
