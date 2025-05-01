#!/usr/bin/env bash

# Get the parent folder, which is the overlay root
__script_dir="$(dirname "$(dirname "$(realpath "$0")")")"

find "${__script_dir}" -name "*.ebuild" -exec dirname {} + | sort -u | while read linea; do pushd $linea; for x in *.ebuild; do ebuild $x manifest; done; popd; done

#egencache --update --repo "$(basename "${__script_dir}")"
