# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit acct-user

DESCRIPTION="User for COSMIC Greeter"
ACCT_USER_ID=-1
ACCT_USER_GROUPS=( cosmic-greeter video )
ACCT_USER_HOME=/var/lib/cosmic-greeter

acct-user_add_deps