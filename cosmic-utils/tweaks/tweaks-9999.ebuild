# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

RUST_MIN_VER="1.85.0"
RUST_MAX_VER="1.92.0"
inherit cargo desktop git-r3 xdg-utils

DESCRIPTION="A tweaking tool offering access to advanced settings and features for COSMIC™"
HOMEPAGE="https://github.com/cosmic-utils/tweaks"
SRC_URI=""
# The actual license needs verification with 'cargo license' in the source directory.
LICENSE="GPL-3.0"

SLOT="0"
KEYWORDS="~amd64" # Adjust keywords as necessary for your architecture

# Dependencies based on the GitHub info (libexpat1-dev, libfontconfig-dev, libfreetype-dev, libxkbcommon-dev)
# These map to Gentoo packages. The 'just' command runner is a build dependency.
DEPEND="
	x11-libs/libxkbcommon
"

RDEPEND="${DEPEND}"

BDEPEND="
	dev-vcs/git
	dev-util/pkgconf
	virtual/pkgconfig
"

# Source code fetched via git-r3 eclass
# Ensure this matches the repository URL from the GitHub link
EGIT_REPO_URI="https://github.com/cosmic-utils/tweaks.git"
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
	doexe "$(cargo_target_dir)/cosmic-ext-tweaks"

	insinto /usr/share/icons/hicolor/scalable/apps
	newicon -s scalable res/icons/hicolor/scalable/apps/icon.svg dev.edfloreshz.CosmicTweaks.svg

	newmenu res/app.desktop dev.edfloreshz.CosmicTweaks.desktop

	insinto /usr/share/metainfo
	newins res/metainfo.xml net.tropicbliss.CosmicExtAppletCaffeine.metainfo.xml
}

pkg_postinst() {
	xdg_icon_cache_update
}
