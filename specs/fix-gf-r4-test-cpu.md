# Task: staging Mac CI is red: test-groupframes-parity-r4 is over the CPU budget

Mac CI on staging fails every push: `test-groupframes-parity-r4` uses 23.9-30.2 CPU s against the 20 s Mac budget (runs 44888530515, 44887414279, 44887216758). Bring it well under (target under 12 s on the Mac, about 20 s hosted) without losing coverage: share one env boot across cases, drop duplicate size permutations, or split it into two files at a natural seam (as #630 did for r3c). Show before/after CPU per file. Test-only change; no addon files. Lint, python; hosted CI green; if you can, run the file on the Mac mini (`ssh -i ~/.ssh/id_ed25519_macs -o IdentitiesOnly=yes leebarry@<mac-mini-tailscale-ip>`, Lua 5.1 in the CI runner toolchain) to show the Mac CPU. One PR to `staging`, `test(groupframes): ...`, label `no changelog`. Do not merge.

**Files it may edit**: `Tools/regression/**`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, run id and the CPU numbers.
