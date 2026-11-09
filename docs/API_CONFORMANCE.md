# API conformance

KstyleUI may use only names that the Forever UI source shows. This page says how a standing guard checks that, what it checks, and what it leaves alone. The guard finds a misspelt or invented name. It does not prove that a call is correct: argument types, return values and timing stay with the regression tests and the in-game pass.

The guard sits beside three older checks and does not repeat them:

- `luacheck` already rejects a bare global that Blizzard neither defines nor reads (`Tools/data/forever_globals.lua`, from `Tools/build/gen_globals.py`).
- `Tools/build/gen_widget_methods.py` and the regression stubs already reject a widget method Forever does not have.
- The taint scan and the rules in the roadmap's Global Constraints still apply.

## Run it

```bash
python3 Tools/hooks/check_api_contracts.py                # problems only; exit 1 when there are any
python3 Tools/hooks/check_api_contracts.py --inventory    # every checked occurrence, as tab-separated rows
python3 Tools/hooks/check_api_contracts.py Core/Init.lua  # only the files you name
python3 -m unittest Tools.tests.test_api_contracts
```

The guard needs no Forever checkout. It reads `Tools/data/forever_api_contracts.json` and `Tools/data/forever_globals.lua`, and it scans the files that the TOCs load. A problem prints as `path:line: category: message`, with a "did you mean" when a close name exists. Fix the addon code. Never add a name to the data to make the guard pass: the data is generated from the source.

## The inventory

`--inventory` prints one row for each checked occurrence: category, status (ok, problem or dynamic), the addon file and line, the name, a detail, and the proof in the Forever source. Its last line counts the rows by category and status and names the source commit. Use it to see everything the guard accounted for, not only the failures. A dynamic row names its operand, such as `<dynamic> opts . template`.

## What it checks

| Category | Found in addon code | Proof |
| --- | --- | --- |
| C_ namespaces and members | `C_X`, `C_X.Name`, `C_X["Name"]`, `pcall(C_X.Name, ...)`, `hooksecurefunc(C_X, "Name")`, a local declared once as `C_X` (an alias), and a local function that looks a member up by name, so `Api("GetCVar")` names `C_CVar.GetCVar`. | The generated documentation, plus members that loaded Blizzard Lua assigns. |
| Events | The event argument of `RegisterEvent`, `RegisterUnitEvent`, the `EventRegistry` and `EventUtil` callbacks, `FrameUtil.RegisterFrameFor(Unit)Events`, the `K.Events` and `ns.Events` `Register` and `RegisterUnit` wrappers, the `pcall` forms of those, calls to an addon function with a parameter named `event`, and tables named like `*events*` that hold names in capitals. | The documented `LiteralName` of each event, plus events that loaded Blizzard Lua registers or lists. |
| Templates | The template argument of `CreateFrame`, `CreateFontString`, `CreateTexture`, the pool creators and `SetElementInitializer`, and `inherits` in addon XML. A comma list is split. | Loaded Blizzard XML elements marked `virtual` or `intrinsic`, and every Font. Templates that the addon's own XML defines are accepted. |
| CVars | The name argument of the Get, Set and Setup CVar calls, `C_CVar` and core `CVars.Exists/Get/Default/Set/SetBitfield` wrappers, a variable or table named like `*cvar*`, and a field assignment ending in `CVAR` or `CVARS` (`local CVAR = "x"`, `Logic.X_CVAR = "x"`, `{ cvar = "x" }`, `CVARS = { { name = "x" } }`). A `cvarLabel` field is not a registry name. | See "CVar proof". |
| Enums and constants | `Enum.X`, `Enum.X.Member` and `Constants.X.Member`, also through an alias. | The documentation, plus Lua that loaded Blizzard code runs. See "Source-use evidence". |
| Mixins | `mixin=` and `secureMixin=` in addon XML, and any global named `*Mixin` in addon Lua. Mixin members are not checked. | Global `*Mixin` tables that loaded Blizzard Lua defines. |
| Global names | `_G.Name`, `_G["Name"]`, `hooksecurefunc("Name", ...)`, and the literal start of `_G["Prefix" .. i]`. | `Tools/data/forever_globals.lua`, which counts names Blizzard defines and names it reads. |
| Blizzard addon names | Any string like `"Blizzard_Foo"`. A deprecated folder, or one Forever does not load, is a problem. | The folders under `Interface/AddOns`. |

A name that the addon itself creates (`_G.X = ...`, a named `CreateFrame`, a global table, its own virtual template) is not Blizzard's to prove and is not reported.

A name that a local holds once as a string literal is read as that string, so `local TEMPLATE = "X"` followed by `CreateFrame("Frame", nil, p, TEMPLATE)` checks X. The same holds for `Slot.TEMPLATE` when the addon sets that field once to a literal. A local that a file declares twice is never read this way.

## Comments and strings

The scanner reads Lua tokens, not text. A name inside a comment, a long string or a string such as `"C_Foo.Bar()"` is never a use. It looks only at call arguments, member chains and a small set of event, CVar and `_G` shapes.

## The data

`Tools/build/gen_api_contracts.py` writes `Tools/data/forever_api_contracts.json`, under 2 MB, one entry per line, with the source commit in its header. Each entry carries `at`: a file number from `files` and a line in that file (`"12:57"` is line 57 of `files[12]`, under `Interface/AddOns`). The guard prints the path and line.

```bash
python3 Tools/build/gen_api_contracts.py --source ~/.capy/work/wow-ui-source-70862 \
  --client-binary "/Applications/World of Warcraft/_forever_/World of Warcraft.app/Contents/MacOS/World of Warcraft" \
  --client-build 1.60.1.70862
```

Regenerate it whenever the Forever build changes, together with `Tools/data/forever_globals.lua`. Without `--client-binary` the generator drops the CVars that only the client proves, and the guard reports them again.

Sections: `namespaces` and `functions` (signature, SecretArguments, SecretReturns, restriction flags and other documented metadata), `secure_only`, `removed`, `events` (payload and flags), `cvars`, `templates`, `enums`, `constants`, `mixins` and `addons`.

Which source counts:

- Only files that a TOC loads on the camelot game type, with the directive rules of `gen_globals.py`. The generator reuses its walker.
- Folders named `Blizzard_Deprecated*` or `Deprecated_*` are not trusted: Forever does not load them. Both name generators classify these as deprecated, including `Deprecated_PaperDoll` (`GetInventorySlotInfo`).
- Names that loaded Lua sets to nil are in `removed` and are subtracted (`Blizzard_EnvironmentCleanup` removes the store and auth namespaces and enums).
- Documentation marked `SecureOnly`, and Lua that a `UseSecureEnvironment` addon or a `[LoadIntoEnvironment secure]` file runs, define nothing that an addon can reach. Such a name is reported as secure-only. Secure files still count as proof that Blizzard registers an event, names a CVar or defines a template, but their API and enum reads do not prove addon visibility.

## Source-use evidence

The documentation omits part of the C API. Where no documentation covers a namespace or an enum, the generator records the members that loaded Blizzard Lua reads and marks the entry `"via": "use"`. `Enum.GameRule` is such a table: the guard accepts `Enum.GameRule.IngameTrackingDisabled`, which Blizzard_Minimap reads, and rejects a member that no loaded code reads. A documented namespace is closed: a member that Blizzard Lua reads but the documentation lacks does not count.

## CVar proof

The source has no list of CVars. A CVar counts when loaded Blizzard Lua passes it as a literal to a CVar call or stores it in a variable or field named like `*cvar*`. An engine CVar that no Lua names is unproven, not nonexistent.

For those, the generator can read the game executable. With `--client-binary` and `--client-build` (which must equal `version.txt` in the source), it takes each CVar name that addon code uses and source lacks, and records it only when the executable holds its exact bytes between two NUL bytes. The data keeps the build, the file's SHA-256 and the offset of each name, and no other part of the string table. A future CVar that neither source nor executable proves fails until the data is regenerated against an executable that holds it. The generator only reads the game file.

## Dynamic and unverifiable sites

The guard lists these and checks only the part it can:

- **A member computed at run time**: `C_X[name]` where `name` is not a literal or a once-set local. The definition of `Api(name)` is listed, and every call `Api("Literal")` is checked.
- **An event held in a variable**: `RegisterEvent(event)` in a loop. The tables the loop reads are checked when their name says "events" (a list of names in capitals always counts; a table of `NAME = true` counts only in a file that registers events from a variable).
- **A template held in a field or argument**: `opts.template`, set elsewhere.
- **A CVar held in a variable**: a name read from a setting at run time.
- **A global name built from a string**: `_G[name .. "Tab"]`. A literal prefix is checked against the known globals; the rest is not.
- **An enum member computed at run time**: `Enum.X[name]`.
- **An unknown member of a Lua-created namespace or enum**: its root exists, but the member remains unverified and is listed as dynamic.

Also outside the guard:

- Fields of values a function returns, frame methods (see `gen_widget_methods.py`), mixin members, arguments and their types, and secret-value rules. The data keeps each function's signature and SecretArguments and SecretReturns flags for a human or a later check; the guard does not read them yet.
- An event name that is not in capitals, or an event table whose name does not say "event".
- A wrapper that the scanner cannot connect to `RegisterEvent`. It finds an addon function by a parameter named `event` and by the `K.Events` shape, and nothing else.
- Two functions with the same name in different files that take an event or a member name differently: a call is read by the definition in its own file, and across files only when every definition agrees.
- Strings built by concatenation, `loadstring`, and names held in data tables.

## When the guard fails

1. Read the proof the guard names, or search the Forever source for the name. A name you cannot find does not exist: use the replacement the docs show.
2. A misspelt name is a bug. An engine CVar the source does not name needs an executable that holds it: regenerate the data with `--client-binary` and name the build in the pull request.
3. A false positive means the scanner reads a pattern wrongly: fix the scanner and add a case to `Tools/tests/test_api_contracts.py`, not an exception to the data.
