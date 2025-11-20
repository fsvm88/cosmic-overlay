# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de

DESCRIPTION="OSD daemon for COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-osd"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH=master

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS=""

RDEPEND+="
	>=media-libs/libpulse-17.0
	>=virtual/libudev-251-r2
"

src_prepare() {
	sed -i 's|.unwrap_or("/usr/libexec/polkit-agent-helper-1")|.unwrap_or("/usr/lib/polkit-1/polkit-agent-helper-1")|' src/subscriptions/polkit_agent_helper.rs || die 'Failed to patch polkit path'
	cosmic-de_src_prepare
}

src_install() {
	dobin "$(cosmic-de_target_dir)/$PN"
}
