# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de

DESCRIPTION="panel for COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-panel"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH=master

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS=""

src_install() {
	dobin "target/$profile_name/$PN"

	insinto /usr/share/cosmic
	doins -r data/default_schema/*
}
