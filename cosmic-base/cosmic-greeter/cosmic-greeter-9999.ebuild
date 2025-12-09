# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

EGIT_LFS=1
RUST_NEEDS_LLVM=1

inherit cosmic-de pam systemd tmpfiles

DESCRIPTION="libcosmic greeter for greetd from COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-greeter"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH=master

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS=""

RDEPEND+="
	~cosmic-base/cosmic-comp-${PV}
	>=acct-user/cosmic-greeter-0
	>=dev-libs/libinput-1.26.1
	>=gui-libs/greetd-0.9.0
	>=sys-libs/pam-1.5.3-r1
"

src_configure() {
	cosmic-de_src_configure --all
}

src_install() {
	local binfile="$(cosmic-de_target_dir)/$PN"
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
	systemd_dounit debian/cosmic-greeter.service

	newtmpfiles "${FILESDIR}/systemd.tmpfiles" "${PN}.conf"
}

pkg_postinst() {
	tmpfiles_process "${PN}.conf"
}
