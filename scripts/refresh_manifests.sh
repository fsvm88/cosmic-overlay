#!/usr/bin/bash

find . -name "*.ebuild" -exec dirname {} + | sort -u | while read -r one_line; do
    pushd "$one_line" || exit 2
    for x in *.ebuild; do
        ebuild "$x" digest
    done
    popd || exit 3
done

egencache --update --repo cosmic-overlay