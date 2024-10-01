# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

EGIT_LFS=1
inherit cosmic-de pam systemd tmpfiles

DESCRIPTION="libcosmic greeter for greetd from COSMIC DE"
HOMEPAGE="https://github.com/pop-os/$PN"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH=master

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

if [[ ${PV} == 9999 ]]; then
	KEYWORDS=""
fi

# As per https://raw.githubusercontent.com/pop-os/cosmic-greeter/master/debian/control
DEPEND="
	${DEPEND}
	>=sys-devel/clang-18
	>=dev-libs/libinput-1.26.1
	>=sys-libs/pam-1.5.3-r1
"
RDEPEND="
	${RDEPEND}
	=cosmic-de/cosmic-comp-${PV}
	>=acct-user/cosmic-greeter-0
	>=gui-libs/greetd-0.9.0
"

src_configure() {
	cosmic-de_src_configure --all
}

src_install() {
	local binfile="target/$profile_name/$PN"
	dobin "$binfile"
	dobin "$binfile-daemon"

	insinto /usr/share/dbus-1/system.d
	doins dbus/com.system76.CosmicGreeter.conf

	insinto /etc/greetd
	doins cosmic-greeter.toml

	systemd_dounit debian/cosmic-greeter-daemon.service

	newpamd debian/cosmic-greeter.pam cosmic-greeter

	# We need to ensure this provides display-manager.service
	sed -i \
		-e '/#\[Install\]/s/^#//' \
		-e '/#Alias/s/^#//' \
		debian/cosmic-greeter.service
	systemd_dounit debian/cosmic-greeter.service

	newtmpfiles "${FILESDIR}/systemd.tmpfiles" "${PN}.conf"
}
