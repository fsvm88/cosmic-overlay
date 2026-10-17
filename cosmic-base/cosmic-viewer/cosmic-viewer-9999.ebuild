# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

COSMIC_GIT_UNPACK=1
inherit cosmic-live desktop

DESCRIPTION="image viewer for COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-viewer"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH=master

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS=""

# Use the system libheif instead of the one vendored by libheif-sys
# (embedded-libheif), which auto-links whatever codecs are on the build host.
# v1_17 (pinned in Cargo.toml) is the minimum libheif API level.
DEPEND=">=media-libs/libheif-1.17:="
RDEPEND="${DEPEND}"
BDEPEND="virtual/pkgconfig"

src_prepare() {
	sed -i -e '/^  "embedded-libheif",$/d' Cargo.toml || die
	grep -q embedded-libheif Cargo.toml && die "failed to drop embedded-libheif feature"
	# Dropping the feature prunes the optional cmake dep from Cargo.lock
	cargo update --offline --workspace || die
	cosmic-live_src_prepare
}

src_configure() {
	cosmic-live_src_configure --all
}

src_install() {
	dobin "$(cosmic-common_target_dir)/$PN"

	domenu res/com.system76.CosmicViewer.desktop

	cosmic-common_install_metainfo res/com.system76.CosmicViewer.metainfo.xml

	insinto /usr/share/icons/hicolor
	doins -r res/icons/hicolor/*
}
