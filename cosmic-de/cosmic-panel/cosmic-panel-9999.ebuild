# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de

DESCRIPTION="panel for COSMIC DE"
HOMEPAGE="https://github.com/pop-os/$PN"

if [ "${PV}" == "9999" ]; then
	EGIT_REPO_URI="${HOMEPAGE}"
	EGIT_COMMIT=683a204
else
	# TODO this is not really working atm
	SRC_URI="https://github.com/pop-os/${PN}/archive/refs/tags/${MY_PV}.tar.gz -> ${P}.tar.gz
				$(cargo_crate_uris)
"
fi

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

# As per https://raw.githubusercontent.com/pop-os/cosmic-panel/master/debian/control

src_install() {
	dobin "target/$profile_name/$PN"

	insinto /etc/cosmic-panel
	doins cosmic-panel-config/config.ron

	insinto /usr/share/cosmic
	doins -r data/default_schema/*
}
