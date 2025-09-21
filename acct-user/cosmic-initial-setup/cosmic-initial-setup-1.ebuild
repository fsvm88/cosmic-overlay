# Copyright 2024 Fabio Scaccabarozzi
# Distributed under the terms of the GNU General Public License v3

EAPI=8

inherit acct-user

DESCRIPTION="User for COSMIC Initial Setup"
ACCT_USER_ID=601
ACCT_USER_GROUPS=( nogroup )
ACCT_USER_HOME=/run/cosmic-initial-setup
ACCT_USER_SHELL=/bin/bash

acct-user_add_deps
