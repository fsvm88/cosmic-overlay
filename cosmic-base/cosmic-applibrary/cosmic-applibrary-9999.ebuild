# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de desktop

DESCRIPTION="app library for COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-applibrary"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH=master

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS=""

src_install() {
	# One of the few where $PN does not apply (would be cosmic-applibrary)
	dobin "$(cosmic-de_target_dir)/cosmic-app-library"

	domenu data/com.system76.CosmicAppLibrary.desktop

	cosmic-de_install_metainfo data/com.system76.CosmicAppLibrary.metainfo.xml

	insinto /usr/share/icons/hicolor/scalable/apps
	doins data/icons/com.system76.CosmicAppLibrary.svg
}
