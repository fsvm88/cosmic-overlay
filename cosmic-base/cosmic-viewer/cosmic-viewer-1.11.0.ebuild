# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de-r2 desktop

DESCRIPTION="image viewer for COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-viewer"

SRC_URI="https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${PN}-${PV}.full.tar.zst"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

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
	cosmic-de-r2_src_prepare
}

src_configure() {
	cosmic-de-r2_src_configure --all
}

src_install() {
	dobin "$(cosmic-common_target_dir)/$PN"

	domenu res/com.system76.CosmicViewer.desktop

	cosmic-common_install_metainfo res/com.system76.CosmicViewer.metainfo.xml

	insinto /usr/share/icons/hicolor
	doins -r res/icons/hicolor/*
}
