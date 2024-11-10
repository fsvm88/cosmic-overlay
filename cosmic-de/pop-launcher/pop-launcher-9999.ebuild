# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de

DESCRIPTION="Modular IPC-based desktop launcher service"
HOMEPAGE="https://github.com/pop-os/launcher"

if [ "${PV}" == "9999" ]; then
	EGIT_REPO_URI="${HOMEPAGE}"
else
	# TODO this is not really working atm
	SRC_URI="https://github.com/pop-os/${PN}/archive/refs/tags/${MY_PV}.tar.gz -> ${P}.tar.gz
				${CARGO_CRATE_URIS}
"
fi

# use cargo-license for a more accurate license picture
LICENSE="MPL-2.0"
SLOT="0"
KEYWORDS="~amd64"

# As per https://raw.githubusercontent.com/pop-os/pop-launcher/master/debian/control

# most of these are used by the plugins
RDEPEND="
${RDEPEND}
>=cosmic-de/pop-icon-theme-${PV}
>=cosmic-de/system76-power-${PV}
sci-libs/libqalculate
>=sys-apps/fd-9
>=x11-misc/xdg-utils-1.2.1-r1
"

src_configure() {
	cosmic-de_src_configure -p pop-launcher-bin
}

_install_plugin() {
	insinto /usr/lib/pop-launcher/plugins/"${1}"
	doins plugins/src/"${1}"/*.ron
	# Symlink to the multicall binary
	dosym -r "/usr/bin/${PN}" /usr/lib/pop-launcher/plugins/"${1}"/"${1/_/-}"
}

src_install() {
	newbin "target/$profile_name/$PN-bin" "$PN"

	_install_plugin "calc"
	_install_plugin "cosmic_toplevel"
	_install_plugin "desktop_entries"
	_install_plugin "files"
	_install_plugin "find"
	_install_plugin "pop_shell"
	_install_plugin "pulse"
	_install_plugin "recent"
	_install_plugin "scripts"
	_install_plugin "terminal"
	_install_plugin "web"

	# This contains also package pop-shell-plugin-system76-power
	# not sure why it gets always split
	insinto /usr/share/pop-launcher/scripts
	insopts -m0755
	doins -r scripts/*
}
