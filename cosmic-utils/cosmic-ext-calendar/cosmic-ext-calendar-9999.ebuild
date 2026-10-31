# Copyright 2026 Rosen Aleksandrov
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-live cosmic-common desktop

DESCRIPTION="Calendar application for the COSMIC desktop"
HOMEPAGE="https://github.com/cosmic-utils/calendar"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH=main

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

# Upstream depends on the "accounts" client library via a sibling path
# (accounts = { path = "../accounts" }), which only exists if both repos are
# checked out next to each other. The library crate lived in the root of
# cosmic-utils/accounts until it was turned into a workspace (2026-08), so
# it is pinned to the last commit before the upstream "accounts" crate got
# new dependencies, matching calendar's Cargo.lock.
ACCOUNTS_REPO_URI="https://github.com/cosmic-utils/accounts.git"
ACCOUNTS_COMMIT="e1ad65e34bc02f98cce48717ab6db65ee04435b2"

RDEPEND+="
	cosmic-utils/accounts
	dev-libs/openssl:=
	dev-libs/wayland
	sys-apps/dbus
	sys-apps/xdg-desktop-portal
	x11-libs/libxkbcommon
"

DEPEND="${RDEPEND}"

BDEPEND="
	virtual/pkgconfig
"

src_unpack() {
	# calendar itself -> ${WORKDIR}/${P}
	git-r3_src_unpack

	# accounts library -> ${WORKDIR}/accounts (resolves "../accounts")
	(
		EGIT_REPO_URI="${ACCOUNTS_REPO_URI}"
		EGIT_COMMIT="${ACCOUNTS_COMMIT}"
		EGIT_CHECKOUT_DIR="${WORKDIR}/accounts"
		git-r3_src_unpack
	) || die "failed to fetch accounts"

	cargo_live_src_unpack
}

src_configure() {
        mkdir -p "${S}/vendor/atspi-common" || die

        ln -s "${WORKDIR}/cargo_home/gentoo/atspi-common/xml" \
                "${S}/vendor/atspi-common/xml" || die

        cosmic-live_src_configure --all
}

src_install() {
	export APPID="dev.edfloreshz.Calendar"

	dobin "$(cosmic-common_target_dir)/${PN}"

	# Upstream resource files are named app.* and renamed by its justfile
	newmenu resources/app.desktop ${APPID}.desktop

	# Upstream installs metainfo to the deprecated /usr/share/appdata
	insinto /usr/share/metainfo
	newins resources/app.metainfo.xml ${APPID}.metainfo.xml

	newicon -s scalable resources/icons/hicolor/scalable/apps/icon.svg ${APPID}.svg

	einstalldocs
}

pkg_postinst() {
	cosmic-live_pkg_postinst

	elog "Calendar accounts (Google, Microsoft, ...) are provided by the"
	elog "cosmic-utils/accounts daemon. Start it with:"
	elog "  systemctl --user enable --now cosmic-accounts.service"
	elog "or let it be launched on demand via D-Bus activation."
}
