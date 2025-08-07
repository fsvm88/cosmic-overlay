# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de desktop

DESCRIPTION="workspaces support for COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-workspaces-epoch"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH=master

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS=""

RDEPEND+="
	>=media-libs/mesa-24.0.4
"

src_install() {
	# one of the few components with custom binary name, no $PN
	dobin "$(cosmic-de_target_dir)/cosmic-workspaces"

	domenu data/com.system76.CosmicWorkspaces.desktop

	insinto /usr/share/icons/hicolor/scalable/apps
	doins data/com.system76.CosmicWorkspaces.svg
}
