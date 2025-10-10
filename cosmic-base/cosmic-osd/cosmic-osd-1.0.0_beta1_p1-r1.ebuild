# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de

DESCRIPTION="OSD daemon for COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-osd"

MY_PV="epoch-1.0.0-beta.1.1"

SRC_URI="
	https://github.com/pop-os/${PN}/archive/refs/tags/${MY_PV}.tar.gz -> ${PN}-${PV}.tar.gz
	https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${P}-crates.tar.zst
	"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND+="
	>=media-libs/libpulse-17.0
	>=virtual/libudev-251-r2
"

src_prepare() {
	sed -i 's|.unwrap_or("/usr/libexec/polkit-agent-helper-1")|.unwrap_or("/usr/lib/polkit-1/polkit-agent-helper-1")|' src/subscriptions/polkit_agent_helper.rs
	cosmic-de_src_prepare
}

src_install() {
	dobin "$(cosmic-de_target_dir)/$PN"
}
