# Copyright 2026 Rosen Aleksandrov
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-live desktop

DESCRIPTION="Clipboard history applet for the COSMIC desktop"
HOMEPAGE="https://github.com/k33wee/clippy-land"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH=main

LICENSE="GPL-3+"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND+="
	dev-libs/wayland
	x11-libs/libxkbcommon
"

DEPEND="${RDEPEND}"

BDEPEND="
	virtual/pkgconfig
"

src_install() {
	export APPID="io.github.k33wee.clippy-land"

	dobin "$(cosmic-common_target_dir)/${PN}"

	# Upstream justfile also installs a Flatpak-only launcher (.sh) and a
	# debug wrapper; neither is needed outside the sandbox.
	# The desktop entry has Exec=cosmic-applet-clippy-land, which is in PATH.
	domenu resources/${APPID}.desktop

	insinto /usr/share/metainfo
	doins resources/${APPID}.metainfo.xml

	# The desktop entry uses the "-symbolic" icon name; upstream installs
	# the same SVG under both names.
	newicon -s scalable resources/icon.svg ${APPID}.svg
	newicon -s scalable resources/icon.svg ${APPID}-symbolic.svg

	einstalldocs
}

pkg_postinst() {
	cosmic-live_pkg_postinst

	elog "To add the applet: COSMIC Settings -> Desktop -> Panel ->"
	elog "Configure Panel Applets -> Clippy Land (you may need to log out and in)."
	elog ""
	elog "Debugging notes (timing logs, running outside the panel) are in"
	elog "DEBUGGING.md in the upstream repository."
}
