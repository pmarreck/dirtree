#!/usr/bin/env bash

# Shared output-cleanup helpers for dirtree and its tests.
if [[ -n "${DIRTREE_OUTPUT_LIB_SOURCED:-}" ]]; then
	return 0
fi
DIRTREE_OUTPUT_LIB_SOURCED=1

strip_ansi() {
	perl -CSDA -pe 's/\e\[[0-9;?]*[ -\/]*[@-~]//g' "$@"
}

strip_tree_icons() {
	sed -E 's/([├└]──)[[:space:]]+[^[:space:]]+[[:space:]]+/\1 /g' "$@"
}

strip_osc8_links() {
	perl -CSDA -0pe 's/\e]8;;.*?\e\\//gs' "$@"
}
