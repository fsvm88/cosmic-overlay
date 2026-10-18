# Copyright 2026 Rosen Aleksandrov
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-live desktop optfeature

DESCRIPTION="Storage and disk utility for the COSMIC desktop"
HOMEPAGE="https://github.com/cosmic-utils/cosmic-ext-storage"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH=main

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND+="
	sys-fs/udisks:2
"

DEPEND="${RDEPEND}"

BDEPEND="
	virtual/pkgconfig
"

#src_configure() {
#	cosmic-live_src_configure --all
#}

src_configure() {
        mkdir -p "${S}/vendor/atspi-common" || die

        ln -s "${WORKDIR}/cargo_home/gentoo/atspi-common/xml" \
                "${S}/vendor/atspi-common/xml" || die

        cosmic-live_src_configure --all
}

src_install() {
	export APPID="com.cosmic.ext.Storage"

	# Application binary
	dobin "$(cosmic-common_target_dir)/${PN}"

	# Desktop entry, metainfo and icon (upstream already names them after the app ID;
	# upstream installs metainfo to the deprecated /usr/share/appdata)
	newmenu resources/app.desktop ${APPID}.desktop

	insinto /usr/share/metainfo
	newins resources/app.metainfo.xml ${APPID}.metainfo.xml

	doicon -s scalable resources/icons/hicolor/scalable/apps/${APPID}.svg

	# Documentation
	einstalldocs
}

pkg_postinst() {
	cosmic-live_pkg_postinst

	elog "Privileged disk operations are handled by UDisks2 through its native"
	elog "Polkit integration, so the application itself runs as your user."
	elog "Make sure udisksd can be started (it is D-Bus activated by default)."

	optfeature "BTRFS support" sys-fs/btrfs-progs
	optfeature "NTFS support" sys-fs/ntfs3g
	optfeature "exFAT support" sys-fs/exfatprogs
	optfeature "FAT / VFAT support" sys-fs/dosfstools
	optfeature "XFS support" sys-fs/xfsprogs
	optfeature "network / cloud mounts (rclone)" net-misc/rclone
}
