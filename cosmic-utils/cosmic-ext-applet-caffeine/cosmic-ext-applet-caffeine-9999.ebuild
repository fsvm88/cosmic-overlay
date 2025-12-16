# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

RUST_MIN_VER="1.85.0"
RUST_MAX_VER="1.92.0"
inherit cargo desktop git-r3 xdg-utils

DESCRIPTION="Caffeine Applet for the COSMIC desktop environment"
HOMEPAGE="https://github.com/tropicbliss/cosmic-ext-applet-caffeine"
SRC_URI=""
# The actual license needs verification with 'cargo license' in the source directory.
LICENSE="GPL-2.0-or-later"

SLOT="0"
KEYWORDS="~amd64" # Adjust keywords as necessary for your architecture

# Dependencies based on the GitHub info (libexpat1-dev, libfontconfig-dev, libfreetype-dev, libxkbcommon-dev)
# These map to Gentoo packages. The 'just' command runner is a build dependency.
DEPEND="
	x11-libs/libxkbcommon
	x11-libs/libXft
	media-libs/fontconfig
	media-libs/freetype
	dev-libs/expat
"

RDEPEND="${DEPEND}"

BDEPEND="
	dev-vcs/git
	dev-util/pkgconf
	virtual/pkgconfig
"

# Source code fetched via git-r3 eclass
# Ensure this matches the repository URL from the GitHub link
EGIT_REPO_URI="https://github.com/tropicbliss/cosmic-ext-applet-caffeine.git"
# Use the master branch or specify a different one
GIT_BBRANCH="master"

# Gentoo's cargo eclass handles most of the build process.
# We override the compile and install phases to use 'just' as requested,
# ensuring it operates within the Portage sandbox (${ED}).

src_unpack() {
	git-r3_src_unpack
	cargo_live_src_unpack
}

src_configure() {
	cargo_src_configure --no-default-features
}

src_compile() {
	cargo_src_compile
}

src_install() {
	exeinto /usr/bin
	doexe "$(cargo_target_dir)/cosmic-ext-applet-caffeine"

	insinto /usr/share/icons/hicolor/scalable/apps
	doicon -s scalable res/net.tropicbliss.CosmicExtAppletCaffeine-empty.svg
	doicon -s scalable res/net.tropicbliss.CosmicExtAppletCaffeine-full.svg

	domenu res/net.tropicbliss.CosmicExtAppletCaffeine.desktop

	insinto /usr/share/metainfo
	doins res/net.tropicbliss.CosmicExtAppletCaffeine.metainfo.xml
}

pkg_postinst() {
	xdg_icon_cache_update
}
