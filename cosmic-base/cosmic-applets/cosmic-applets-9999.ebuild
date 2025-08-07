# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit cosmic-de desktop

DESCRIPTION="applets for COSMIC DE"
HOMEPAGE="https://github.com/pop-os/cosmic-applets"

EGIT_REPO_URI="${HOMEPAGE}"
EGIT_BRANCH=master

# use cargo-license for a more accurate license picture
LICENSE="GPL-3"
SLOT="0"
KEYWORDS=""

RDEPEND+="
~cosmic-base/cosmic-icons-${PV}
"

_install_icons() {
	local icons_folder="$1"/data/icons
	if [ -d "$icons_folder" ]; then
		insinto /usr/share/icons/hicolor
		doins -r "$icons_folder"/*
	fi
}

_link_applet() {
	# Symlink to the multicall binary
	dosym -r "/usr/bin/${PN}" "/usr/bin/$1"
}

_install_applet() {
	_link_applet "$1"

	# Insert icons
	_install_icons "$1"

	# Insert desktop file
	domenu "${1}/data/${2}.desktop"
}

_install_button() {
	# Insert icons
	_install_icons "$1"

	# Insert desktop file
	domenu "${1}/data/${2}.desktop"
}

src_install() {
	# This git project now creates one multicall binary
	dobin "$(cosmic-de_target_dir)/${PN}"

	# Install applets:
	# - s-link to multicall binary
	# - icons
	# - desktop file
	_install_applet "cosmic-app-list" "com.system76.CosmicAppList"
	_install_applet "cosmic-applet-a11y" "com.system76.CosmicAppletA11y"
	_install_applet "cosmic-applet-audio" "com.system76.CosmicAppletAudio"
	_install_applet "cosmic-applet-battery" "com.system76.CosmicAppletBattery"
	_install_applet "cosmic-applet-bluetooth" "com.system76.CosmicAppletBluetooth"
	_install_applet "cosmic-applet-input-sources" "com.system76.CosmicAppletInputSources"
	_install_applet "cosmic-applet-minimize" "com.system76.CosmicAppletMinimize"
	_install_applet "cosmic-applet-network" "com.system76.CosmicAppletNetwork"
	_install_applet "cosmic-applet-notifications" "com.system76.CosmicAppletNotifications"
	_install_applet "cosmic-applet-power" "com.system76.CosmicAppletPower"
	_install_applet "cosmic-applet-status-area" "com.system76.CosmicAppletStatusArea"
	_install_applet "cosmic-applet-tiling" "com.system76.CosmicAppletTiling"
	_install_applet "cosmic-applet-time" "com.system76.CosmicAppletTime"
	_install_applet "cosmic-applet-workspaces" "com.system76.CosmicAppletWorkspaces"

	# Install buttons:
	# - icons
	# - desktop file
	_install_button "cosmic-panel-app-button" "com.system76.CosmicPanelAppButton"
	_install_button "cosmic-panel-launcher-button" "com.system76.CosmicPanelLauncherButton"
	_install_button "cosmic-panel-workspaces-button" "com.system76.CosmicPanelWorkspacesButton"

	# cosmic-panel-button is only s-linked to the multicall binary
	_link_applet "cosmic-panel-button"

	# Install metainfo
	cosmic-de_install_metainfo data/com.system76.CosmicApplets.metainfo.xml

	# Install default schema
	insinto /usr/share/cosmic
	doins -r cosmic-app-list/data/default_schema/*
}
