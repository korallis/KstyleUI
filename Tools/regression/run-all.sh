#!/usr/bin/env bash
# run-all.sh: run every Tools/regression/test-*.lua from the repository root under CI's interpreter, with a time and memory budget per file.
pick_python() {
	local candidate
	for candidate in "${KSTYLEUI_PYTHON:-}" "$HOME/.local/share/wow-dev/venv/bin/python" \
		"$HOME/.local/share/wow-dev/venv/Scripts/python.exe" py python3 python; do
		[ -n "$candidate" ] || continue
		py=("$candidate")
		[ "$candidate" = py ] && py+=(-3)
		if "${py[@]}" -c 'import sys' >/dev/null 2>&1; then
			KSTYLEUI_PYTHON=$("${py[@]}" -c 'import sys; print(sys.executable)')
			export KSTYLEUI_PYTHON
			return 0
		fi
	done
	echo "No Python found; install Python 3 or set KSTYLEUI_PYTHON." >&2
	return 2
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
	cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 2
	pick_python || exit 2
	exec "${py[@]}" Tools/regression/run_all.py "$@"
fi
