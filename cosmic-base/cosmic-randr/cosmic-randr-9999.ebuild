# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de

DESCRIPTION="CLI utility for displaying and configuring wayland outputs from COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-randr"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH=master

# use cargo-license for a more accurate license picture
LICENSE="MPL-2.0"
SLOT="0"
KEYWORDS=""

src_install() {
	dobin "$(cosmic-de_target_dir)/$PN"
}
