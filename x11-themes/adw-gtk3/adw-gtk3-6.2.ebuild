# Copyright 2023-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit meson

DESCRIPTION="The theme from libadwaita ported to GTK-3"
HOMEPAGE="https://github.com/lassekongo83/adw-gtk3"
SRC_URI="https://github.com/lassekongo83/adw-gtk3/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="LGPL-2.1"
SLOT="0"
KEYWORDS="amd64 arm64"

# See https://github.com/lassekongo83/adw-gtk3/issues/293
# as to why dart-sass-bin is required
# dev-ruby/sass has been deprecated upstream at least for a few years now
# and adw-gtk3 >= 5.10 does not build with it
BDEPEND="|| (
	>=dev-util/dart-sass-bin-1.89.2
	>=dev-util/dart-sass-1.93.2
)"
RDEPEND=">=gui-libs/gtk-4.16.0:4"
