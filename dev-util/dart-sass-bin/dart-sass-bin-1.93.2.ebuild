# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Source overlay: https://github.com/BlueManCZ/edgets

EAPI=8

DESCRIPTION="The reference implementation of Sass, written in Dart."
HOMEPAGE="https://sass-lang.com/dart-sass"

SRC_URI="
	amd64? (
		elibc_glibc? ( https://github.com/sass/dart-sass/releases/download/${PV}/${P/-bin/}-linux-x64.tar.gz )
		elibc_musl? ( https://github.com/sass/dart-sass/releases/download/${PV}/${P/-bin/}-linux-x64-musl.tar.gz )
	)
	arm64? (
		elibc_glibc? ( https://github.com/sass/dart-sass/releases/download/${PV}/${P/-bin/}-linux-arm64.tar.gz )
		elibc_musl? ( https://github.com/sass/dart-sass/releases/download/${PV}/${P/-bin/}-linux-arm64-musl.tar.gz )
	)
"

S="${WORKDIR}/${PN/-bin/}"

LICENSE="MIT"
SLOT="0"
KEYWORDS="amd64 arm64"
RESTRICT="mirror"

QA_PREBUILT="*"

# dart-sass is the successor to dev-ruby/sass
# has been deprecated and unsupported for a few years upstream now
# the user, adw-gtk3, has migrated to dart-sass since >=6.0
# the two have incompatible CLI options
RDEPEND="!dev-ruby/sass"

src_install() {
	exeinto /usr/lib64/dart-sass
	doexe src/dart
	insinto /usr/lib64/dart-sass
	doins src/sass.snapshot

	newbin "${FILESDIR}/sass-wrapper" "sass"

	insinto /usr/share/${PN}
	doins src/LICENSE
}
