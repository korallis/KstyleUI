"""Export the tables abilities.py reads from the installed game client, read-only.

Usage: python3 Tools/icons/casc_export.py --build 1.60.1.70840
                                          [--wow-dir "/Applications/World of Warcraft"] [--product wowf]
                                          [--out Tools/data/db2cache/<build>] [--tools ~/.local/share/wow-dev]

Use it when wago.tools is down, then run abilities.py with --from-dir pointing at the output folder.
Install the tools once with Tools/icons/install-casc-tools.sh.

TACTTool (TACTSharp) extracts each table's DB2 file from the client's CASC storage, and DBC2CSV
(DBCD with the WoWDBDefs definitions) converts it to the same CSV format wago.tools serves. Both
tools run in a temporary folder, which holds TACTTool's listfile and cache. TACTTool only reads the
game folder, and this script never writes there.
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import abilities  # noqa: E402

DEFAULT_WOW_DIR = Path("/Applications/World of Warcraft")
DEFAULT_TOOLS = Path.home() / ".local" / "share" / "wow-dev"
INSTALL_HINT = "run Tools/icons/install-casc-tools.sh"


def read_build_info(wow_dir, product):
    """Return the .build.info row for product as a dict keyed by column name.

    .build.info is a pipe-separated table whose header names look like "Version!STRING:0".
    An active row wins over an inactive one.
    """
    path = Path(wow_dir) / ".build.info"
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines:
        raise ValueError(f"{path} is empty")
    header = [name.split("!", 1)[0] for name in lines[0].split("|")]
    rows = [dict(zip(header, line.split("|"))) for line in lines[1:] if line.strip()]
    matches = [row for row in rows if row.get("Product") == product]
    if not matches:
        raise ValueError(f"{path} has no {product} install")
    return sorted(matches, key=lambda row: row.get("Active") != "1")[0]


def _run(command, cwd):
    result = subprocess.run([str(part) for part in command], cwd=cwd, capture_output=True, text=True)
    if result.returncode != 0:
        output = (result.stderr or result.stdout).strip().splitlines()[-5:]
        raise RuntimeError(f"{Path(command[0]).name} failed with exit {result.returncode}: {' / '.join(output)}")


def export_tables(build, wow_dir, out_dir, product, tacttool, dotnet, dbc2csv, tables=abilities.TABLES):
    """Write one <Table>.csv per table into out_dir and return out_dir.

    Every table is extracted, converted and parsed in a temporary folder before any file reaches
    out_dir, so a failure leaves out_dir as it was.
    """
    # The tools run in a temporary folder, so relative paths must be resolved first.
    wow_dir, out_dir, tacttool, dotnet, dbc2csv = (
        Path(path).absolute() for path in (wow_dir, out_dir, tacttool, dotnet, dbc2csv)
    )
    installed = read_build_info(wow_dir, product).get("Version")
    if installed != build:
        raise ValueError(f"the installed {product} client is {installed}, not {build}; pass --build {installed}")
    for tool in (tacttool, dotnet, dbc2csv):
        if not Path(tool).exists():
            raise FileNotFoundError(f"{tool} is missing; {INSTALL_HINT}")

    with tempfile.TemporaryDirectory(prefix="kstyleui-casc-") as temporary:
        work = Path(temporary)
        listfile = work / "tables.txt"
        listfile.write_text("".join(f"dbfilesclient/{table.lower()}.db2\n" for table in tables), encoding="utf-8")
        extract = work / "extract"
        _run([tacttool, "-p", product, "-d", wow_dir, "-m", "list", "-i", listfile, "-o", extract], work)

        stage = work / "db2"
        stage.mkdir()
        for table in tables:
            source = extract / "dbfilesclient" / f"{table.lower()}.db2"
            if not source.exists():
                raise FileNotFoundError(f"TACTTool did not extract {table} ({source.name})")
            source.rename(stage / f"{table}.db2")

        _run([dotnet, dbc2csv, stage], work)
        for table in tables:
            converted = stage / f"{table}.csv"
            if not converted.exists():
                raise FileNotFoundError(f"DBC2CSV did not convert {table}; its definitions may not cover {build}")
            if not abilities.load_csv(converted):
                raise ValueError(f"DBC2CSV wrote no rows for {table}")

        out_dir.mkdir(parents=True, exist_ok=True)
        for table in tables:
            partial = out_dir / f".{table}.csv.tmp"
            shutil.copyfile(stage / f"{table}.csv", partial)
            os.replace(partial, out_dir / f"{table}.csv")
    return out_dir


def main(argv=None):
    parser = argparse.ArgumentParser(description="Export the ability tables from the game client, read-only.")
    parser.add_argument("--build", required=True, help="the installed build, such as 1.60.1.70840")
    parser.add_argument("--wow-dir", type=Path, default=DEFAULT_WOW_DIR, help="game folder that holds .build.info")
    parser.add_argument("--product", default="wowf", help="TACT product code (wowf is WoW Forever)")
    parser.add_argument("--out", type=Path, help="output folder (default Tools/data/db2cache/<build>)")
    parser.add_argument("--tools", type=Path, default=DEFAULT_TOOLS, help="folder install-casc-tools.sh filled")
    parser.add_argument("--tacttool", type=Path, help="TACTTool executable (default <tools>/casc/TACTTool/TACTTool)")
    parser.add_argument("--dotnet", type=Path, help="dotnet executable (default <tools>/dotnet/dotnet)")
    parser.add_argument("--dbc2csv", type=Path, help="DBC2CSV.dll (default <tools>/casc/DBC2CSV/DBC2CSV.dll)")
    args = parser.parse_args(argv)

    out_dir = args.out or abilities.DEFAULT_CACHE / args.build
    try:
        export_tables(
            args.build,
            args.wow_dir,
            out_dir,
            args.product,
            args.tacttool or args.tools / "casc" / "TACTTool" / "TACTTool",
            args.dotnet or args.tools / "dotnet" / "dotnet",
            args.dbc2csv or args.tools / "casc" / "DBC2CSV" / "DBC2CSV.dll",
        )
    except (OSError, ValueError, RuntimeError) as err:
        print(f"casc_export: {err}", file=sys.stderr)
        return 1
    print(f"Exported {len(abilities.TABLES)} tables for {args.product} {args.build} to {out_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
