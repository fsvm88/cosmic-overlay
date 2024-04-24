# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8
inherit meson

DESCRIPTION="PopOS GTK theme for COSMIC DE"

HOMEPAGE="https://github.com/pop-os/gtk-theme"

LICENSE="CC-BY-SA-4.0"
SLOT="0"
KEYWORDS="~amd64"

if [ "${PV}" == "9999" ]; then
	inherit git-r3
	EGIT_REPO_URI="${HOMEPAGE}"
fi
IUSE="+icons gnome-shell gnome-shell-gresource +gtk +sounds +sessions +default +dark +light"

BDEPEND="
>=dev-build/meson-1.3.2
>=dev-lang/sassc-3.6.2
>=dev-libs/glib-2.78.3
"
RDEPEND="
${RDEPEND}
>=dev-libs/glib-2.78.3
>=x11-libs/gdk-pixbuf-2.42.10-r1
>=x11-libs/gtk+-2.24:2
>=x11-libs/gtk+-3.24:3
>=x11-themes/gtk-engines-murrine-0.98.2-r3
"

src_configure() {
	local emesonargs=(
		$(meson_use icons)
		$(meson_use gnome-shell)
		$(meson_use gnome-shell-gresource)
		$(meson_use gtk)
		$(meson_use sounds)
		$(meson_use sessions)
		$(meson_use default)
		$(meson_use dark)
		$(meson_use light)
	)
	meson_src_configure
}
