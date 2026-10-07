# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

DESCRIPTION="COSMIC DE Sound Theme"
HOMEPAGE="https://github.com/pop-os/cosmic-sound-theme"

SRC_URI="https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${PN}-${PV}.full.tar.zst"

# use cargo-license for a more accurate license picture
LICENSE="CC-BY-SA-4.0"
SLOT="0"
KEYWORDS="~amd64"

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

src_prepare() {
	default

	sed -e 's/@ThemeName@/COSMIC/' src/index.theme.in > src/index.theme
}

src_install() {
	insinto /usr/share/sounds/COSMIC
	doins src/index.theme
	doins -r src/stereo
}
