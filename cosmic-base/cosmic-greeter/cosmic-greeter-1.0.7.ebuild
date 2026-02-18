# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

RUST_NEEDS_LLVM=1

inherit cosmic-de-r2 pam systemd tmpfiles

DESCRIPTION="libcosmic greeter for greetd from COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-greeter"

SRC_URI="https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${PN}-${PVR}.full.tar.zst"

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND+="
	~cosmic-base/cosmic-comp-${PV}
	>=acct-user/cosmic-greeter-0
	>=dev-libs/libinput-1.26.1
	>=gui-libs/greetd-0.9.0
	>=sys-libs/pam-1.5.3-r1
"

src_configure() {
	# Required for some crates to build properly due to build.rs scripts
	export VERGEN_GIT_COMMIT_DATE='Tue Feb 17 09:54:02 2026 -0700'
	export VERGEN_GIT_SHA=2cbb199a1613e7431a642ad601b8b7cb2546bbea

	cosmic-de-r2_src_configure --all
}

src_install() {
	local binfile="$(cosmic-common_target_dir)/$PN"
	dobin "$binfile"
	dobin "$binfile-daemon"
	newbin "$PN-start.sh" "$PN-start"

	insinto /usr/share/dbus-1/system.d
	doins dbus/com.system76.CosmicGreeter.conf

	insinto /etc/greetd
	doins cosmic-greeter.toml

	systemd_dounit debian/cosmic-greeter-daemon.service

	newpamd "${FILESDIR}"/cosmic-greeter.pam cosmic-greeter

	# We need to ensure this provides display-manager.service
	sed -i \
		-e '/#\[Install\]/s/^#//' \
		-e '/#Alias/s/^#//' \
		debian/cosmic-greeter.service
	systemd_dounit debian/cosmic-greeter.service || die "failed to patch systemd unit via sed"

	newtmpfiles "${FILESDIR}/systemd.tmpfiles" "${PN}.conf"
}

pkg_postinst() {
	tmpfiles_process "${PN}.conf"
}
