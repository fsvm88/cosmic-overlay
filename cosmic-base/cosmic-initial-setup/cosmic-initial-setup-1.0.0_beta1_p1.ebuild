# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

COSMIC_GIT_UNPACK=1

inherit cosmic-de

DESCRIPTION="initial setup program for COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-initial-setup"

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
	acct-user/cosmic-initial-setup
	~cosmic-base/pop-appstream-data-1.0.0_beta1_p1
	~cosmic-base/cosmic-icons-${PV}
"
