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

DEPEND="dev-libs/glib"
BDEPEND="
dev-build/meson
dev-lang/sassc
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