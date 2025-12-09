# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

RUST_NEEDS_LLVM=1

inherit cosmic-de pam systemd tmpfiles

DESCRIPTION="libcosmic greeter for greetd from COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-greeter"

MY_PV="epoch-1.0.0-beta.9"

SRC_URI="
	https://github.com/pop-os/${PN}/archive/refs/tags/${MY_PV}.tar.gz -> ${PN}-${PV}.tar.gz
	https://github.com/fsvm88/cosmic-overlay/releases/download/${PV}/${P}-crates.tar.zst
	"

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
	export VERGEN_GIT_COMMIT_DATE='Mon Nov 24 15:24:05 2025 -0700'
	export VERGEN_GIT_SHA=201d8a1bc408f4b92ecc9da074ace26a3098463d

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
