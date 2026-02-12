# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

DESCRIPTION="icon set COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-icons"


SRC_URI="https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${PN}-${PVR}.full.tar.zst"
S="${WORKDIR}/${PN}-${PVR}"

# use cargo-license for a more accurate license picture
LICENSE="CC-BY-SA-4.0"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND+="
	>=cosmic-base/pop-icon-theme-3.5.1
"

src_unpack() {
	debug-print-function ${FUNCNAME} "$@"

	pushd "${DISTDIR}" >/dev/null || die
	mkdir -p "${S}" || die

	for archive in ${A}; do
		case "${archive}" in
		*.full.tar.zst)
			tar -x -I 'zstd --long=31' -C "${S}" -f "${archive}" --strip-components=1
			;;
		*)
			tar -x -C "${S}" -f "${archive}" --strip-components=1
			;;
		esac
	done
	popd >/dev/null || die
}

src_install() {
	insinto /usr/share/icons/Cosmic
	doins -r freedesktop/scalable
	doins -r extra/scalable
	doins index.theme
}
