# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

DESCRIPTION="icon set COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-icons"

MY_PV="epoch-1.0.0-beta.2"

SRC_URI="
	https://github.com/pop-os/${PN}/archive/refs/tags/${MY_PV}.tar.gz -> ${PN}-${PV}.tar.gz
	"
MY_P="${PN}-${MY_PV}"
S="${WORKDIR}/${MY_P}"

# use cargo-license for a more accurate license picture
LICENSE="CC-BY-SA-4.0"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND+="
	>=cosmic-base/pop-icon-theme-3.5.1
"

src_install() {
	insinto /usr/share/icons/Cosmic
	doins -r freedesktop/scalable
	doins -r extra/scalable
	doins index.theme
}
