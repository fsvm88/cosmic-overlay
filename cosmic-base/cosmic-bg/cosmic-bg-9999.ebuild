# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-live

DESCRIPTION="display background service for COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-bg"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH=master

# use cargo-license for a more accurate license picture
LICENSE="MPL-2.0"
SLOT="0"
KEYWORDS=""
IUSE+=" +avif"

RDEPEND+="
	avif? ( >=media-libs/dav1d-1.4.2 )
"

src_configure() {
	local myfeatures=(
		$(usev avif "avif")
	)

	cosmic-live_src_configure --no-default-features
}

src_install() {
	dobin "$(cosmic-common_target_dir)/$PN"

	insinto /usr/share/cosmic/com.system76.CosmicBackground/v1
	doins data/v1/*
}
