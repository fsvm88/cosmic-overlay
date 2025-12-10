# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

DESCRIPTION="Wallpapers for the COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-wallpapers"

MY_PV="epoch-1.0.0"

SRC_URI="
	https://github.com/pop-os/${PN}/archive/refs/tags/${MY_PV}.tar.gz -> ${PN}-${PV}.tar.gz
	"
MY_P="${PN}-${MY_PV}"
S="${WORKDIR}/${MY_P}"

# As of 2024-11-01, the git repo now provides a LICENSE
LICENSE="CC-BY-SA-4.0"
SLOT="0"
KEYWORDS="~amd64"

BDEPEND="
	media-gfx/imagemagick
"

src_unpack() {
	debug-print-function ${FUNCNAME} "$@"

	pushd "${DISTDIR}" >/dev/null || die

	mkdir -p "${S}" || die

	for archive in ${A}; do
		case "${archive}" in
		*-crates.tar.zst)
			tar -x -I 'zstd --long=31' -C "${WORKDIR}" -f "${archive}"
			;;
		*-repo.tar.zst)
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
	insinto /usr/share/backgrounds/cosmic
	doins original/*
}
