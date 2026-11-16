"""Install the pinned Windows Lua 5.1.5 and luacheck 1.2.0 binaries."""

import hashlib
import io
import os
from pathlib import Path
import subprocess
import urllib.request
import zipfile

ASSETS = (
    ("lua.zip", "https://downloads.sourceforge.net/project/luabinaries/5.1.5/Tools%20Executables/lua-5.1.5_Win64_bin.zip",
     "5f34cf7d40a20a587ea351482a4207d93b92ef6f1983e910a13338253819fe93"),
    ("luacheck.exe", "https://github.com/lunarmodules/luacheck/releases/download/v1.2.0/luacheck.exe",
     "0f1c69c4d09f1ebb4d8df14c215e4553e2e639bd4cb7bf3c639b0daa6198317b"),
)


def main():
    destination = Path(os.environ.get("PREFIX", Path.home() / ".local")) / "bin"
    downloads = {}
    for name, url, checksum in ASSETS:
        executable = destination / ("lua5.1.exe" if name == "lua.zip" else name)
        flag, version = ("-v", "Lua 5.1.5 ") if name == "lua.zip" else ("--version", "Luacheck: 1.2.0")
        if executable.exists():
            installed = subprocess.run([str(executable), flag], capture_output=True, text=True)
            output = installed.stdout + installed.stderr
            if installed.returncode == 0 and output.startswith(version):
                print(output.strip())
                continue
        with urllib.request.urlopen(url, timeout=120) as response:
            data = response.read()
        if hashlib.sha256(data).hexdigest() != checksum:
            raise SystemExit("SHA-256 mismatch for " + name)
        downloads[name] = data
    destination.mkdir(parents=True, exist_ok=True)
    if "lua.zip" in downloads:
        with zipfile.ZipFile(io.BytesIO(downloads["lua.zip"])) as archive:
            archive.extractall(destination)
    if "luacheck.exe" in downloads:
        (destination / "luacheck.exe").write_bytes(downloads["luacheck.exe"])
    subprocess.run([str(destination / "lua5.1.exe"), "-v"], check=True)
    subprocess.run([str(destination / "luacheck.exe"), "--version"], check=True)


if __name__ == "__main__":
    main()
