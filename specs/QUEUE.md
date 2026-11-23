# KstyleUI work queue (coordinator, 2026-11-16)

Router picks agent/model. Each task: dispatch -> worker_done -> cross-family verify (--avoid author) -> fixes -> merge (squash, --match-head-commit). Every spec ends with specs/_footer.md.

## Merged
#411 onboarding, #412 parallel CI, #414 skip proven push, #415 release reuse, #416 portable runner, #418 quest card + RestedXP Items, #419 packager tags.

## Running
- Options overlaps (slider labels, clipped value, Medallions preview): ctx_1bda1bf5b680.
- #410 unit cluster: author fixing verify findings (ctx_4a5f330c0725).
- #413 fs.lua: verifier ctx_b62f1493697e; then author rebases onto staging (conflict in test_affected.py with #416).
- #417 render harness: verifier ctx_63d5247e8cc4.
- Dead Medallions code removal: ctx_743cc7a5b075.

## Next, by dependency
- After #413: PR 6 Python suite on Windows + LF check + flaky timing-margin tests (LEE-1537) + the C:\dev\null collision; tighten #419's cleanup test from substring to exact match (verify M9); drop Known failing python line.
- After #413: PR 7 CPU-time + peak-RSS budgets (Windows wall-clock overruns, perf headroom); then PR 8a profile heavy families, 8b+ per family.
- After #417: LEE-5826 fix the off-grid pixel regions (hud_reference rows back to pre-#417 counts). Before release.
- After #410: rune rim polish (LEE-1540); vehicle leave button in hub gap (LEE-1547). Parallel.
- When merging #417: keep the trailer "Baseline-Growth: LEE-5826" in the squash commit body. PR 6 also: run check-suppressions with SUPPRESSION_BASELINES=Tools/regression/pixel_allow.tsv in gate.sh (verify-417 Attention 6).
- Small follow-up test: aura style switch Orbs->Medallions, Frames<->Orbs and a real combat-lockdown switch (verify pr410v3 Attention); fold into the acceptance fixes.
- R6 slot policy: investigate the 2026-11-15 runner load first (no change without data).
- Last: acceptance of staging by a non-author family; README pictures (Tools/render/readme.py) + v0.2.3 prep (origin/release/v0.2.3-prep 354b2ba4, update for everything merged); tag only after the staging run is green; ff main, annotated tag v0.2.3, check zip, send Lee the link.

## Backlog (2026-11-17)
- Worker-slot starvation: a polling runner waited 30+ min for its last slot while 3-4 parallel gates kept taking freed slots (perf-4 worker, PID 34908). Fold into R6 slot policy: FIFO ticket or priority to runs closest to done.
- perf-3 (action-bar cooldown double pass): write spec and dispatch after #445 merges.
- UI audit (Lee 2026-11-17: score /10 for performance, effects, aesthetics, player needs; finesse/elegance/polish first; HTML mockup of proposed changes): lenses ctx_503fc2171390 aesthetics, ctx_1737c62ed6a2 effects, ctx_8350315d252d performance, ctx_7ab14f959262 player -> C:/Users/leeba/.cache/kstyleui-audit/*.md. When all four report: dispatch a synthesis worker (scorecard + ranked 10/10 plan + self-contained HTML before/after mockup), then publish it as an Artifact (load artifact-design first).
- Crest debuff fan (Caith-style, all player-applied debuffs, Medallions only): ctx_2bfd9da3d486.
- Audit now 12 workers: each lens on Claude, Codex (gpt-6-astra) and Grok (grok-4.7). Files: <lens>.md (Claude, or Grok for player), <lens>-codex.md, <lens>-grok.md, player-claude.md. Synthesis must compare the three models per lens (agreements = high confidence).
- Mac CI CPU-budget flakes under load: #445 attempt 1 failed 65 CPU-budget/headroom checks on unchanged modules, passed on rerun (run 44194112825). Investigate with LEE-5827.
- Render harness: RENDER_FX=cast/stopped/ready/burst draw nothing visible at peak (effects audit); shoot.sh treats C:/... backdrop paths as relative (needs /c/...). Ticket both.
- Render harness scene.lua alpha-multiply bug: README frame_raid.jpg shows an opaque dispel tile (aesthetics audit). Fix + retake picture.
- shoot.sh cannot write PNGs from Git Bash on Windows (performance audit patched scratch copies). Ticket with the other harness bugs.
- Arena (pstack arena steps): candidates ctx_8f50c24604a2 claude-fable, ctx_c25e5776183e codex-astra, ctx_4df555b3e50a grok -> ~/.cache/kstyleui-audit/arena/candidate-*. Next: cross-judge (non-Claude: codex gpt-6.1-sol readonly) scores the 3 against the rubric in specs/arena-audit.md; I read all three, pick base, graft, verify at 1440/390, load artifact-design skill, publish as Artifact, send Lee the link. Then delete audit cache bulk (21 GB) except arena/final.
- Mac mini CI host: corespotlightd ~113% CPU (12 days) + fseventsd ~99% while CI runs; 3 runner jobs on 12 cores -> CPU-budget overruns (#445, #447 retries). Fix needs Lee: System Settings > Spotlight > Search Privacy > add ~/ci-host (or sudo mdutil). Then revisit R6 slot policy.
- #446 ready to merge at 7a6aa243 (spot-checked, CI green); held until perf fix 2 (lazy regions, ctx_7bf93f8269e4) PR is in, as promised. Then remove worktree emperor.
- Audit delivered inline 2026-11-18 (compact view); full page in chat-scratch/audit. Cleanup pending: ~/.cache/kstyleui-audit (21 GB) after Lee reviews.
- Crest debuff fan #453: Lee chose NEXT release (v0.2.6), not v0.2.5. Review ctx_ba6f9afa1208 running; merge only after v0.2.5 is tagged.
- RELEASE BLOCKER: #452 (merged b9c96465) stack overflow opening Options GroupFrames (repro ~/.cache/verify-452/repro-options-overflow.lua). Fix: ctx_ef2234e07eb2. Then merge #446 (its test-groupframes-preview-small failed with #452 combined; re-run on merged tree), green staging, tag v0.2.5.
- Lesson: before merging a PR whose CI ran on an older base, run its new tests on the merged tree (caught #452 x #446).
- #453 fan fixes at 20a17ca4 (base a81b7922, pre-#452). After v0.2.5 tag: rebase on staging, run its tests on the merged tree, spot-check Auras.lua filter vs settings, merge for v0.2.6.
- v0.2.5 RELEASED 2026-11-18 (de549a2d). Replies posted (CF comment, GH #443 closed, #444). Store descriptions updated. Next: #453 fan for v0.2.6; audit plan batches need Lee sign-off; Spotlight on Mac mini; delete ~/.cache/kstyleui-audit bulk.
- 2026-11-18 Lee: DO IT ALL (whole audit plan, Recipe A, options default off) + release. Wave 1: A ctx_9a8d4f60a061, P1 ctx_1163d644501e, Hb ctx_839df4506d47, Z ctx_ff822373a7fa; #453 rebase ctx_c5ff2f246945. Wave 2 after A: C+D; after P1: P7+H-a (H1,H2,H3,H4,H10, Nameplates/Slab); G-a rails (G1,G2,G7,G10,G11), G-c (G5,G6,G8), P-b (P3,P4,P5,P6,P12); after Hb: G-b (G4,G9). Wave 3: E (after C/D,H-a), F (after D,P-b). Then v0.2.6 changelog + release + reply on #443.
- Also dispatched now: G-a ctx_0d1aa456e038 (G1,G3,G7,G10,G11), G-c ctx_2925aba4c982 (G5,G6,G8). G2 moves to the C+D wave (GroupFrames/Medallions.lua shared with A3).
- Stub follow-up: wow.lua SetAtlas keeps the previous texture path; the client replaces it (found by G-a in skins_windows AddOns gallery).
- E3 spec note: interrupt fills the bar (EndTimer 1); A1 label ink follows what is under the label, so dark ink on hostile red after E3.
- #456 (P part 1) review ctx_bfd0fbdd0a7d. H-a (H1-H4,H10,P7) dispatched ctx_d7d5c85f9e95 (feature playbook now).
- P7 slice guards (Base.lua LayoutSlice/ColorSlice skip) moved to P-b. Frames cast bars (H1 Frames part + G6) owned by G-c: both 14 tall, name inside at 12.
- Lee 2026-11-18: A4 meter fill clamp REJECTED (keep class-colour bars, Details style); only text outline/shadow. Everything else in the plan approved.
- README/store pictures to real game scenery (no AI plate): ctx below. Retake again right before v0.2.6 tag. Ask Lee for in-game captures of Frames/Orbs and Alt+Z plates.
- Addon bug (from #457 review): KstyleUI_ActionBars/Slab.lua:593,595,609,612 copy GetAlpha() into vertex alpha -> hub particles and combat sweeps never show in client, glow/glyphs/runes at alpha^2. Fix in the C+D batch (owns Slab.lua) + in-game check. Hold Medallions README retake until fixed.
- Stub gap: stubs/wow.lua:526-535 GetAlpha/GetVertexColor share one alpha; fix in a test-infra follow-up (with the SetAtlas texture-path gap).
- Merged: #457 (Z), #456 (P part 1). P-b dispatched ctx_e26240e9d988 (P3,P4,P5,P6,P12,P7 slice tail). Remaining waves: C+D(+G2, Slab alpha bug) after A #459; G-b (G4,G9) after Hb; E after C/D+Ha; F after D+P-b.
- Welcome page branding (Lee 2026-11-18): dispatched below; check PNG logo loads in Forever.
- Lee 2026-11-18: Personal Resource Display off by default (new user screenshot). Sent to H-a ctx_d7d5c85f9e95.
- Lee 2026-11-18: tooltip at cursor out of combat, anchor in combat, new default. Dispatched below.
- Lee 2026-11-18: EVERYTHING TOGGLEABLE. Sent to all feature workers; #459 needs a follow-up adding toggles after its review; add to every future spec (C+D, G-b, E, F).
- P-b: P5a hidden-next-show and P6 blocked (secret aura constraints); P3 partial (6654 alive, protected aura art remainder). Accepted.
- Lee bugs 2026-11-18: world map blank until zoom ctx_1144e3153c97; bags drop on EMPTY ctx_7d254b129026; minimap tooltips beside map -> tooltip worker ctx_2d05c199063b. #459 follow-ups+toggles ctx_a1c2b5aad415.
- World map blank-until-zoom: PARKED (Lee could not reproduce, 2026-11-18). Trace: ~/.cache/parked/worldmap-blank-report.txt + specs/bug-worldmap-blank.md. Not a release blocker.
- Known Beast issue: Tools/tests/test_render_size.py PUC subprocess timeouts (60-90 s) under load, also on base. Consider a load-aware timeout ticket.
- Lee: nameplate debuffs bigger (~22u, readable timers) in Minimal and Dungeon; Dungeon keeps icon size, adds % + 12u bar. Sent to H-a.
- HudStyle thumbnails re-shoot (G4 part) moved into #463 (welcome) ctx_8eee3a505d91: Medallions thumb showed 2 rows.
- Merged #459 (ink+toggles), #465. Dispatched C ctx_38396ab32a07, D(+G2+Slab alpha bug) ctx_5ab8b643dfd3. Remaining: G-b (G4 rest, G9) after Hb; E after C/D+Ha; F after D+P-b.
- G8 remainder: RestedXP chrome pixel-grid fix lives in Core/Skin.lua (not done by G-c); fold into a later batch.
- 4K chat alignment + CDM mid-screen (player screenshot): dispatched below.
- Swing timer restyle (Lee: weird, does not blend) added to the CDM/chat worker ctx_8cd088ba7848 (owns the centre strip).
- Lee: new spells -> Add new to bars button beside Update bars. Dispatched below.
- CORRECTION 2026-11-18: client texture alpha is ONE value (SetAlpha = vertex alpha, last write wins; proof v0.2.2 hub fix). #457 Z1 multiply model was wrong; the 'Slab alpha bug' was not a bug (reverted in #470); A7 dispel sample IS opaque in client -> fixed in fix-harness-texture-alpha task.
- Tester 0xDAB: party frames appear late after joining (dispatched below); druid "layout per form" request pending Lee clarification.

- v0.2.7: role/spec customisation (ctx_d482bd9ae996, feat-role-spec-customisation.md). Hold merge until after the v0.2.6 tag (Lee, 2026-11-18).

- Follow-up (from #473 review): Core Hush has no SetColorTexture hook for other textures; check whether a recolour can revive hidden textures there.

- #475 (v0.2.7, ctx_fb51d10432eb terminal structworker_1e9e0940...): approved, cuts + existing-player-off migration done at a770465c. After the v0.2.6 tag: ask for rebase (renumber migration after #460s 37 (and #472s 36)), green CI, merge.

- 2026-11-18 Lee: v0.2.6 WAITS for the remaining audit batches, done fast. Dispatched E-a ctx_4ac600dfb2a5 (E1,E2), E-b ctx_50f5ba367b35 (E3,E4,E5), F-a ctx_9c1f97d7de55 (F1,F2), F-b ctx_ea8766174dd7 (F3,F5,F7), F-c ctx_8ad59cd3b25b (F6,F8), G8 ctx_a13b4c3cae41. F4 skipped (taste call, needs in-game captures). G-b (G4 rest, G9) dispatches when #460 merges. Each gets one combined review (correctness + minimal code).

- Follow-up after v0.2.6: reload VM ceiling raised 15.5M -> 15.7M by #460/#469 (new features). Perf task: bring reload back under 15.5M, pixel-identical.
- CurseForge: our v0.2.5 reply to the_truth_82 is posted twice (duplicate); ask Lee before deleting one.

- guard.mjs bug: the push gate keys on the session cwd HEAD (hook input cwd), not the directory a command cds into; key on the target repo of the git command instead.

- v0.2.6 RELEASED 2026-11-18 22:08 UTC (tag on 6f1f6caf; main fast-forwarded). GitHub release + Wago live; CurseForge Under Review. Replies posted: GH #443, CurseForge. Raid README picture kept old (opaque live-aura tile needs in-game check). Next: #475 rebase for v0.2.7.

- Follow-ups from #487 review: RestedXP card and quest-card height only ever grow (base too); Speedrun Guide and menu headers differ from KstyleUI headers (consistency audit).

- Consistency follow-up: party bars draw a fill-end spark, tooltip and tracked bars do not; Blizzard fallback tracked bars stay ~24px (Edit Mode) vs mirror 12.
- Accuracy follow-ups (owner): whole-percent rounding to match Blizzard (rounds up) across modules; cooldown numbers with Readable countdowns off; paragon reputation; swing timer haste/parry/on-next-swing needs one in-game PLAYER_SWING capture.

- guard.mjs bug 2: a command with two PR-merge calls only gates the first PR number; and the regex also matches the words inside echo/printf text. Gate each merge, match only real command words.

- HOLD lifted: #500 merged.

- After the Discord release-post workflow (ctx_1e0bce2b0319, PR #492) merges: delete GitHub repo webhook 714060475 (release -> Discord /github) so v0.2.7 posts once; paste store descriptions (bugs -> Discord) on CurseForge and Wago at the v0.2.7 release.

- Follow-up (consistency): when the player picks Questie's tracker, it is unskinned; card it in the KstyleUI style (Questie frames via its own API) like the RestedXP guide.

- PENDING: answer layout guard question msg_f86eddd4f231 with the staging SHA when #500 merges.

- Login chat nag: "KstyleUI: Turn on the Cooldown Manager in Options > Gameplay > Advanced Options..." prints on every login (11 times in Evil's chat log). Show it once per account, or add a "don't show again", or only when the Cooldowns module is on and the CVar is off.

## Customisation parity (approved 2026-11-19; report: kstyleui-evidence/customisation-parity/report.md)
- In flight: 1 text/tags (ctx_0b3ffe4d3a1d), 2 party/raid/solo Shown (ctx_804b08c564ac), 7 layout per spec.
- Next, when 1 merges: 3 shared BarRows (UnitFrames and Nameplates overlap with 1) and 5 aura filter row (Nameplates overlaps with 1).
- Next, when 2 merges: 4 attach-to-element plus match width, then 6 Layout Mode extras (both in Core/Layout).

- CI gap: the staging push skipped Lua through the green-marker rule although #507 merged on top of #505 and #506, so the reload budget went red unnoticed (found by the #518 worker). Markers must prove the exact merged tree, or a staging push must always run the perf budget tests. Fix after #517.

- Display resize cost: a real screen-size change (alt-tab in exclusive fullscreen, or a resolution change) costs 17.7M-22.6M addon instructions per round, more than a whole reload (13.8M), measured by the #518 worker. It is not a leak, but it is a hitch on every alt-tab. Make it cheaper (pixel-identical): debounce, and re-lay out only what the size change touches.

## v0.2.7 = everything (Lee, 2026-11-19 ~20:10, no cut-off)
- Merged so far: #505 #506 #507 #508 #510 #516 #517 #519.
- Stacked now: data bar 3+4 (ctx_7099fa3cc379, on #512), cust 4 attach (ctx_5688c3b2d078, on #521).
- Next: data bar 5 (micro menu dock and Medallions slab dock) when #512 merges; cust 3 (BarRows) and 5 (aura filter) stacked on batch 1 once its PR opens; cust 6 (Layout Mode extras) stacked on cust 4.
- Release only after all of these merge, then: notes, pictures, tag, store descriptions, Discord post edit.

- RestedXP skin: SectionCap and Path restyles share an unordered weak-key Style registry, so the same code produces two header heights depending on allocation order (found by the perf-resize worker). Make the order deterministic.

- #532 optional cuts (about 40 lines): 10 dead memo guards and 8 preview wrappers (report: kstyleui-evidence/perf-headroom/verify-532.md). Do after v0.2.7.

- 2026-11-20 Lee decisions: percentages round like Blizzard (yes, ctx_5071a33e647e with paragon), no cooldown numbers when Readable countdowns is off, paragon reputation yes, deleted the duplicate v0.2.5 CurseForge reply. The v0.2.6 CurseForge reply is also posted twice; ask before deleting. Swing timer: Lee will post an in-game capture.

- Stub follow-up (from #544 review): SetTexture after SetAtlas keeps the old atlas in both stubs; the client clears it, so scene.lua:1171 would draw the atlas over the new file. Fix in stubs/wow.lua with a test.

- guard.mjs (after router PR #1): the merge gate keys on the literal command, so a merge whose head comes from $(...) and is re-run with extra commands appended is gated again. Key on the PR number plus the resolved head. DONE: router PR #2.
- guard.mjs: a target given as a Git Bash path (cd /c/Users/... before a push) fails to resolve on Windows ("cannot resolve the commit"); convert /c/... to C:/... before git -C. Also a pre-existing inert-text case: a single-quoted command substitution makes the whole command count, so a quoted mention can use up the one-time review, and printf text containing one is blocked (review-pr2.md).
- Router checkout C:/Users/leeba/orca-jev-router sits on branch fix/guard-command-targets with PR #2 files synced from origin/main (staged) and someone else's uncommitted orca-route.mjs edit; move it to main once that edit is committed.

- Questie card: first row sits ~15px under the header vs ~22px on the RestedXP card (render after #549). Match the gap.

- Client is now 1.60.1.70959 (navmesh spike, 2026-11-20); AGENTS.md and the API source say 70862 at 9dc84f0. Check whether Gethe/wow-ui-source forever has a newer commit, then regenerate forever_globals and the API contracts.
- NPC positions: QuestieDB at runtime + in-game recorder (world map batch 5). Lee may ask Wowhead for permission (email drafted 2026-11-20).

- Recurring (3 times on 2026-11-20): workers run the full local Lua suite and starve the 10 shared slots. Encode it as a check: run_all.py refuses a full or all-files --affected run when another run_all holds slots, unless KSTYLEUI_FULL=1, and the message names the Beast speed rule.

- Reload budget creeping: 15.01M of 15.7M after #558 (2026-11-20; was 14.86M this morning). Look for the next lazy-load win before it blocks a PR.

- After #561: merge the two stacked Medallions slab notes in KstyleUI_ActionBars/Settings.lua (:260-261) into one; drop the redundant ns.SyncVisibilities() calls (Module.lua:385, :458); fold consumables clickThrough/reverse/visibilityBuilder into the defaults literal. Render the reversed bar at 2560x1440, 5120x1440 and 3840x2160.

- Staging Mac CI went red on 4 merges (2026-11-20): consumables clearance tests at 20.0-21.2 CPU s vs 20. Hosted PR shards only warn and are noisy (2x slower), so nothing caught it. Fix dispatched (ctx_9717f86603b5). Follow-up check: a gate step that fails a PR when a test file it touches runs above ~16 Mac-equivalent CPU s, with calibration from the Mac runs.

- Router/guard: Cursor workers cannot run any shell command, because guard.mjs returns "invalid JSON" to the Cursor hook (2026-11-20, ctx_9e15582dfa6e). Fix the guard output for Cursor or keep Cursor out of the KstyleUI routing until fixed; re-dispatched with --avoid cursor.

- Router: --avoid comma lists are broken in committed main (fixed in router PR #4 follow-up).

- Frames parity F1 must also apply the #568 review cuts: GroupFrames/Indicators.lua:277-281, UnitFrames/Auras.lua:576-582 hoist, CastBar.lua:960 redundant issecretvalue, Nameplates/Cast.lua:269/303 repeated restore; unify the nameplate full-opacity label wording.

- v0.2.8.1 hotfix (Lee approved 2026-11-20): once #570 (ScrollList) and the consumables-move PR (ctx_acaaafbcb488) are merged and green, branch hotfix/v0.2.8.1 from tag v0.2.8, cherry-pick both squash commits, add a CHANGELOG/RELEASE_NOTES v0.2.8.1 entry, run checks.yml (workflow_dispatch) on the branch including Mac, then tag v0.2.8.1 on that branch (main stays at v0.2.8; the next release fast-forwards main to staging). Update Evil's thread to Released.

- Consumables: after Layout Undo or Reset the bar stays released (attached=false) instead of re-docking (Layout.lua:1584 Reset, :1626 Undo bypass Update/Set). Reset should re-attach. Optional 2-line cut at Consumables.lua:83-85.

- CI batch 3 (safer releases: refuse to publish after red staging proof; check the uploaded zip; trim YAML-snapshot tests) waits until the Discord announcement PR (ctx_b711a727961b) merges, since both edit release.yml and test_workflows.py.

- Core parity follow-up (L1/L2, P1/P2, A1-A3, W1/W2) must also fix the #572 review notes: Mode.lua:504-505 mover tooltip should name Alt+scroll at default settings; General window rows (Pages.lua:422-427) need specific help, and Reset should not also move the window; cuts Profiles.lua:207 issecretvalue and :186 label table (reuse Pages.MODULE_LABELS).

- When #567 merges: wake ctx_ca67c81c0a53 (combat parity batch 2) with orca orchestration send.

- (LIFTED) HOLD staging merges and manual Mac runs until ctx_b8459fdb4667 (CI batch 1, PR #574) reports its uncontended 5-shard run (requested 17:00).

- Model catalog: after both research reports (Fable 5.2 + Astra) land in kstyleui-evidence/model-catalog/, start Fable 5.2 (JEV_USER_NAMED=1 worker-start --agent claude --model claude-fable-5-2) to combine them and write the final catalog.json + any small orca-route.mjs criteria change as a PR to korallis/orca-jev-router (clone to a temp dir; never touch the live checkout with its uncommitted orca-route.mjs edit). Global change: affects every repo.

- Model catalog owner decisions (2026-11-20): keep Muse contributor mode; PAY FOR FIRST-PASS QUALITY (route most implementation to Opus/Astra/Fable-class, not Sol by default); no Gemini 4 for now. New models found: gpt-6.2-astra and gpt-6.2-sol (2026-11-17), not yet in the local Codex proxy catalog; verify availability before adding.

- Regression README.md:46 says a fixed 3:2 split of Mac slices; GitHub hands jobs out dynamically. Reword when next touched.

- Discord repost after the short-highlights PR merges: gh workflow run release.yml --ref staging -f tag=v0.2.7 -f message_ids=1573220581153833091,1573220586422013973,1573220591664627815,1573220596576297082,1573220602251321407,1573220607817154566 ; v0.2.8 ids 1573322594965397676,1573322600724037653,1573322606101270560,1573322611566584000,1573322618373935145,1573322623687856272 ; v0.2.8.1 ids 1573378534502834199,1573378540144169073. Then gh release edit each past tag with its rewritten section.

- Router PR #4 owner decisions (2026-11-20): keep the xhigh effort ladder; keep Composer and zcode; keep jev-latest. After merge: add gpt-6.2-astra and gpt-6.2-sol to ~/.codex/cpa-gui-model-catalog.json, then sync the live router checkout (without touching its uncommitted orca-route.mjs edit; merge carefully). Since Cursor stays, fix the guard.mjs "invalid JSON" for Cursor hooks next.

- Pre-existing strict guard hits on staging Options pages at 1080: Power text dropdown ellipsis; group preview Orrin overlap. Fix in a small PR.

- Release plan (Lee, 2026-11-20): polish-audit work ships in the release AFTER v0.2.9; v0.2.9 carries what is on staging now (road routes, parity batches, CI, announcements). Keep polish PRs off staging until v0.2.9 is tagged, or land them behind the cut.

- Polish audit: 12 auditors (Muse + Sol/Grok + Fable 5.2 + Astra per lens A-D). When all are in kstyleui-evidence/polish-audit/, start Fable 5.2 (JEV_USER_NAMED=1 worker-start --agent claude --model claude-fable-5-2) to combine them into one ranked plan for the release after v0.2.9; the plan must show how KstyleUI massively surpasses the LATEST CaithUI (gold standard), then the others.

- Render guard: gallery_layout --strict fails on a stale Tools/render/guard_allow.tsv line 16 (polish audit B-fable). Remove the stale line.

- gallery_groupframes --strict fails in Medallions and Frames on staging (aura tile over text; polish audit A-fable). Trace and fix.

- PARITY SCALE-UP (Lee 2026-11-20: v0.2.9 waits for every Missing-fits row). Module workers via specs/parity-module.md (sed MODULE/FOLDER/MODKEY/ROUND). Started r1: auras, combattext, minimap, chat. Start after batch-3 fixes merge: unitframes+groupframes+nameplates (after #583), cooldowns+meters (after #585), tooltips+qol+databars+bags (after #586), options+layout (after #584). Re-dispatch next round per module until its README has 0 Missing, fits.

- POLISH PLAN APPROVED (Lee 2026-11-20, all 13 recommendations). Build after v0.2.9 is tagged, in PLAN.md batch order (F1-F5 foundations, then P6-P19, S1-S9). Items changing the default look (2 clean screen, 3 casts to owner, 5 slab caps/pips/crest, 6 Medallions default) need four-screen renders shown to Lee before merge. Plan: ~/.cache/kstyleui-evidence/polish-audit/PLAN.md and PLAN.html.

- Staging bug: at 5120x1440 with cast text outside the bar, a tracked-buff icon covers the cast right end (parity-combat-3/fix/staging_text_outside_5120x1440.png). Also Reskin.Stop does not restore swipe/timer. Fix for v0.2.9.

- Roadmap posted to #announcements 2026-11-20 21:02, message id 1573443520474120352 (from PR #587 branch). Update in place later with: gh workflow run release.yml --ref staging -f roadmap=true -f message_ids=1573443520474120352 (after #587 merges; edit docs/ROADMAP.md first).

- Auras round 2: 2 rows left (default/custom buff and debuff bars) need Core/Setup/Layouts.lua layout defaults; allow it (no new top-level locals). Start after #589 merges.

- French gallery_options strict fails at Auto 1080: truncated sample name "Hurleur du givre" in KstyleUI_UnitFrames/Preview.lua (pre-existing). Fix with the plan-bugs batch or after.

- Data Bars round 2 must also build the friends LIST tooltip (Friends Tooltip Cap and Show Notes rows moved from Minimap).

- Hotfix v0.2.8.2 contents: #590 (RestedXP, pending fix), #588 merged (welcome text, French Options footer, data bar text, colour-vision health), #600 (ten bugs, pending fix + v0.2.8.1 port branch hotfix/port-600). #588 must be ported onto v0.2.8.1 too (check conflicts).

- DECISION (Lee 2026-11-20): hotfix v0.2.8.2 is cut FROM STAGING once #590 (RestedXP) and #600 (ten bugs) merge, after a quick readiness check; main must first be merged back into staging (main has the v0.2.8.1 notes commit), then fast-forward main to staging and tag.

- 2026-11-20 late: merged #590, #600, #596. v0.2.8.2 content FROZEN at staging b94abee8; notes worker ctx_0540fb567d4f (notes-0282.md). HOLD merges of #597/#601/#595/#602/#599 until v0.2.8.2 tagged.
  Tag plan: after notes PR merges and staging Mac CI green on it: main := commit-tree <staging tree> -p origin/main -p origin/staging (main has v0.2.8.1 commits, no ff), push main, tag v0.2.8.2 on it.
  Reviews in flight (codex): #598 QoL ctx_106080f0ab10, #608 Auras r2 ctx_004bc597930a, #609 Minimap r2 ctx_b5540734be35.
  Rebased (locale) + pushed, CI pending: #597 b4ebbd62, #601 b2284a16, #595 6f7d56ce, #602 950277fd. #599 fixed 7b236073 green (held).
- Lee 2026-11-20: another machine is building a combo point / class resource module. When its PR arrives, it goes in the next release that is still open: v0.2.8.2 if the notes have not merged yet (then refreeze content + update notes), otherwise v0.2.9. Give it one cross-family review like any PR.
- relocale now three-way per key (stage 1 base); _locfix.py <old_head> repairs an already-rebased branch. #597 746b70fe and #601 1694805a re-pushed with Frost Howler restored. Fix rounds: #598 ctx_09f153415b52, #609 ctx_db2c643f9eab, #608 ctx_4fd6c197f2b2.
- #604 Options/Layout fixed 62d31808 green (held). Decisions: parity extras stay OFF by default (parity rule 'defaults keep today's look' wins over everything-toggleable ON for new extras that change the look); out-of-allowlist edits accepted (rebase conflict resolution with #600). Round 2 adds the 12 module mirror rows.
- #611 Nameplates r2 (46 rows, incl. combo points on target plate: check overlap with Lee's other-machine combo point module when it lands) under review.
- 2026-11-21 00:xx: v0.2.8.2 TAGGED (main 8c8d1855 = staging 9e66bf63 tree, parents main+staging). Release run 44840511086 (watch bv2nyf7sf). After it: update Discord bug threads (Evil + RestedXP) to Released, update roadmap post in place.
  Merged after tag: #599 #597 #601 #595 #602 #604 #608 (relocale + local module tests, no re-CI; staging Mac CI is the proof).
  Other machine PRs (Opus): #605 #606 #607 #610 #614 (crest resource jewels = the combo point module -> v0.2.9). Codex reviews: 605 ctx_2d676ebebbea, 606 ctx_317c0abb7b90, 607 ctx_2e5bfea8dda0, 610 ctx_b65bb58c2eb3, 614 ctx_3fda0de4142b. 605/606/614 have luacheck/mixed-line-ending failures; fix rounds via fixpr with spec pr-NNN.md.
  #611 has combo points on target plate: reconcile with #614 (one source of truth for combo-point reading).
  In flight: fixers #598 ctx_09f153415b52, #609 ctx_db2c643f9eab, #611 ctx_9010af687099, #613 ctx_9df51b611396; #603 fixer ctx_58f258b35ff5.
  Next: round 2 for Tooltips/Cooldowns/GroupFrames/UnitFrames/Meters/Bags/Options(+12 mirror rows)/CombatText; DataBars r2 after #603 (friends tooltip).
- v0.2.8.2 released + Discord embed posted; bug threads already closed earlier (no update needed). Roadmap post edited in place (PR #615). Merged #598, #609. Round 2 for merged modules starts once the 8 fixers in flight drop to ~4 (Beast render load).
- Merged #605, #614 (crest jewels, toggle ON default), #611. Round 2 started: unitframes ctx_68d0c9efbdd1, groupframes ctx_ee35e699d098. Still to start r2: tooltips, cooldowns, meters, bags, options(+mirror rows), combattext; databars r2 after #603.
- Merged #607. r2 cooldowns started.
- Merged #606. r2 meters started.
- Merged #603 (Great Vault deferred). #610 conflicts in Strip.lua -> rebase worker ctx_3dd561ab814e. r2 bags started. DataBars r2 (friends tooltip) after #610 merges.
- Merged #613 (Chat done: 0 left). Tooltips, Auras, CombatText have 0 Missing-fits. r2 options started. Left to start: databars r2 (after #610), QoL r2, Minimap (2 rows -> databars friends), Nameplates r3, Chat none.
- Merged #610. r2 databars started (+friends tooltip, dock glyphs). Reviews: #616 ctx_0cee9223e330, #618 ctx_1f4cbf1231e9, #619 ctx_75ee161ba0f7, #620 ctx_0a1a7e1ef5b6. Next rounds needed: groupframes r3 (124), cooldowns r3 (45), unitframes (pending r2), meters (pending r2), QoL r2, nameplates r3.
- Lee 2026-11-21: split UF/GF backlogs across parallel workers. UF r3a MiniFrames ctx_85472df39414, r3b SharedAppearance ctx_69fdc9bc236e, r3c SharedBars ctx_b78796f692fd, r3d Cast/auras+player cast ctx_a2b8315f72c2; GF r3a VisualIndicators ctx_612a9b46b9c8, r3b RaidFrames pages ctx_b4cd3916f7c4, r3c FramesPages+VisualBars ctx_ace169d62881. Merge order per module: #616/#617 first, then splits one at a time (real Settings.lua conflicts -> rebase worker).
- Merged #620 (Options r2; new toggle Profile tools > Import account choices ON). Options left: chat input font + per-spec cooldown rows (Missing, fits again), WagoUI adapter -> Options r3 (small) later.
- BUG (from #621 fixer): on staging the docked 250-wide threat card (Meters 'Both') overlaps the Frames stance bar (15u) and Medallions bar2/XP strip (21-69u) at 2560x1440. Fix after #621 merges.
- Merged #618. Cooldowns r3 started.
- Lee 2026-11-21: once the Onward nameplate bug is fixed, release a hotfix with completed bug fixes. Investigation ctx_6785618a3e6d. Local branch hotfix/v0.2.8.3 at /c/Users/leeba/.cache/wt-hotfix = v0.2.8.2 + cherry-picks #605 #607 #606 (tests pass). Then: cherry-pick Onward fix (if KstyleUI's), add CHANGELOG + RELEASE_NOTES v0.2.8.3 (branded), run checks.yml workflow_dispatch on the branch incl. Mac, ff main, tag v0.2.8.3; mirror the notes to staging via PR.
- #622 databars r2 in review. Left: extra bars (needs databars.strip2 in Layouts.lua) -> databars r3.
- BUG (from #619 fixer): shell_parity Options BAGS title clipped 1.9u at 2560x1440 and 5120x1440 under --strict, already on staging. Onward error: NOT ours (Onward/Target.lua:216 measures plate; restricted since 8.2). Report + player reply in ~/.cache/kstyleui-evidence/onward-nameplate/report.md.
- v0.2.8.3 hotfix: branch hotfix/v0.2.8.3 35264b0d (v0.2.8.2 + #605 #607 #606 + notes); checks run 44857931737 (watch bx7u98is9). On green: push main ff to 35264b0d, tag v0.2.8.3. Notes mirror PR #624 to staging.
- Merged #621 (Meters done). Bug fix dispatched: threat overlap + BAGS title (bug-threat-overlap-bags-title.md) -> next hotfix.
- v0.2.8.3 TAGGED (main ff 35264b0d). Release watch biiek6boq. #624 notes mirror now also updates Notes.lua (test-options-notes: every CHANGELOG version must be pasted into KstyleUI_Options/Notes.lua + translated) - REMEMBER for every future release notes PR. Watch bstf38xvp.
- BUG (from #617 fixer): target 'Debuffs and buffs' filter puts timers-below over the buff row (predates #617). Queue a fix.
- Merged #622. DataBars r3 started. #630 GF r3c in review. Fixers: #625 #627 #628.
- Threat docked card now 180 wide in Both (bug fix). BAGS clip = harness gap; follow-up PR (A) fixes the stub's natural FontString size (43 scene JSONs change, harness only).
- #623 QoL r2 in review (ctx_0ab2dbc09773). QoL 83 left -> after #623 merges, split r3 in two: (A) MovementAlert, BattleRes/Bloodlust, range text, Shifter; (B) RaidTools, /way, /cd (.luacheckrc line) and the rest.
- #633 Cooldowns r3 in review. Cooldowns r4 (20 left): keybind needs ActionBars ShortKey moved to Core; Mirror Key Presses needs ActionBars press signal -> allow Core/ActionBars edits in r4.
- BUG (from #623 fixer): Options-page render fails --strict on QoL HUD alert lines drawn under the Options window (on staging too).
- Merged #623, #630. QoL r3 split started.
- Merged #633. Cooldowns r4 started.
- Merged #634 (threat overlap fix -> next hotfix v0.2.8.4 with #635's preview commit d66dd1af if approved). #635 review ctx_665c30e828af. Bug worker (target timers + QoL alerts) dispatched.
- Merged #628, #631. Staging Missing-fits: UF 132 (incl. rows in open #626/#629), GF 74 (incl. #632), NP 73 (incl. #627), QoL 84 (r3a/r3b running), CD 22 (r4 running), DB 6 (r3 running), Options 2, Bags 1. Next: once #626/#629 merge start UF r4 split (by section); after #632 GF r4 split; after #627 NP r4 split; Options r3 + Bags r3 small.
- Merged #632. GF 40 left -> GF r4 single worker started.
- Merged #627. Reload 12.82M/13.0M -> perf headroom task dispatched. NP r4 started.
- BUG (from #635): Minimap preview restyle is path-dependent (scale down then back up does not restore piece sizes).
- Merged #635. Hotfix v0.2.8.4 = #634 + #635 preview commit + #637 (in fix) + minimap restyle bug (dispatched).
- Merged #626, #629. UF ~48 left -> r4a/r4b split started.
- Merged #637 (target timer lane). v0.2.8.4 hotfix waits on minimap restyle bug (ctx_d6e73a0d14ad). Fix commits on staging: #634 5a37eded0, #635 preview commit inside 8c2363a4d (cherry-pick only KstyleUI_UnitFrames/Preview.lua part), #637 f88d51afe.
- #642 GF r4 (11 rows) review. GF 29 left -> r5 after #642 (friendly boss 5, extra frames 9, pets 3, bar indicators 3, misc). #643 perf PR: reload 12.93->12.00M.
- BUG (from #641): with drawer set to stay open, Drawer:Layout reads toggle width before Column:Refresh resizes it (anchor drift up to 3.7u; Map.Refresh same order -> may affect live minimap).
- Merged #641. Hotfix v0.2.8.4 port worker dispatched (hotfix-0284.md). On green: ff main to hotfix/v0.2.8.4, tag v0.2.8.4, merge notes PR.
- Merged #643 (reload ~11.9M), #644, #640. Started CD r5, NP r5, perf lazy defaults.
- Merged #638. QoL 27 left -> r4 started.
- v0.2.8.4 TAGGED (main ff 4a23ed13). Release watch brl1an3ry. Notes #646 merged. Follow-ups dispatched: buff row vs bag strip + flaky perf-frames UNIT_FLAGS headroom.
- Merged #645. UF r5 started (4b leftovers, Layouts/visibility allowed).
- Merged #642. GF r5 started (+ default Medallions heal-icon overlap fix -> hotfix candidate).
- #650 QoL r4 review. QoL left after: Hide Item Transforms (needs picked list) + Time Spiral x6 (deferred, needs in-game capture).
- #652 perf defaults (-261k exact) in review. Next perf targets: Widgets IsSecret (598k), Layouts.Fits (534k).
- Merged #649 (Cooldowns done), #648 (Nameplates done). Backlog: UF 13 (r5 running), GF 29 (r5 running), QoL 27 (#650 fixing), Options 2 + Bags 1 + Auras 1 -> parity-odds worker.
- Merged #650. QoL left: 6 Time Spiral + 4 Shifter (deferred, need in-game evidence from Lee) + Hide Item Transforms (r5 started). ASK LEE: do deferred-pending-in-game rows block v0.2.9?
- Merged #651 (buff row clearance + perf-frames UNIT_FLAGS cheaper) -> next hotfix v0.2.8.5 candidate, with GF r5's default heal-icon fix.
- Merged #652 (reload -244k exact; ~11.5M now).
- STAGING MAC RED: test-groupframes-parity-r4 24-30 CPU s (> 20). Fix dispatched. Release blocked until green.
- DECISION (Lee 2026-11-21): v0.2.9 = merge the rounds already open (#653 UF r5, #654 GF r5, parity-odds PR ctx_b46c70d381f9, plus in-flight: UF r6 ctx_cd7b75c8d238, QoL r5 ctx_96147504c023, Orrin fix ctx_d6f6beba779d, gf-r4 test CPU fix ctx_ee3d63e259a0), then release v0.2.9 from staging. Do NOT start new parity rounds; anything not started -> v0.2.10 (GF r6, QoL in-game rows).
  Release steps: staging Mac green -> notes PR (CHANGELOG + RELEASE_NOTES + Notes.lua What's new, branded, crest jewels highlighted) -> main := commit-tree staging tree, parents main+staging -> tag v0.2.9 -> roadmap post update (v0.2.9 out, v0.2.10 = remaining parity).
- Lee 2026-11-21: release cadence is my call, aim >= 1 release/day. Parity rounds may continue (GF r6 etc.) and roll into the next release.
- Hotfix v0.2.8.5 (#651 port) dispatched ctx_a1b6097248e0. GF heal-icon default fix (in #654) -> next hotfix as soon as #654 merges (or v0.2.9 if that comes first).
- Lee 2026-11-21: Discord invite featured at top of addon description; descriptions/README always current with new renders. Worker dispatched (docs-store-refresh.md). After v0.2.9 puts images on main: paste master into CurseForge + Wago via Orca browser.
- #657 last rows review. Auras consumable-count row left -> v0.2.10.
- #658 raid indicator: D (approved design KSTY-47/57: indicator covers the name tail only while shown); ship preview fix only.
- Merged #653 (UF r5), #659 (gf-r4 test split), #658 (Orrin preview). v0.2.9 waits on: #654 fix, #656 review, #657 review, UF r6, store refresh, staging Mac green.
- IN-GAME CHECK for Lee (v0.2.9): QoL Tools > Hide item transforms: enable, wear a Skeleton costume out of combat, confirm it drops with no blocked-action popup.
- Merged #656, #660, #657. v0.2.9 waits: #654 fix, store refresh (ctx_b359a657e16e).
- v0.2.8.5 TAGGED (main ff bb862468). Release watch b44p6cpkv. Notes #661 merged.
- (closed) #662 dock render white line = brief hit spark, already under text; guard test only.
- Merged #662 (store refresh). Spark-over-text bug dispatched. v0.2.9 waits only on #654 now (then notes, tag, paste store pages).
- v0.2.9 notes worker ctx_b3cf74583d7e (notes-029.md). Message it when #654 merges to rebase.
- Merged #654. Notes #664 rebasing. GF r6 started (v0.2.10).
- #664 v0.2.9 notes merged; staging 441984ca, Mac run 44902728559 (watch b4l3pomb7). On green: main := commit-tree staging tree -p origin/main -p origin/staging; push main; tag v0.2.9; watch release; paste store pages (CurseForge + Wago) via Orca browser; update roadmap post.
- v0.2.9 RELEASED. Store pages pasted (CurseForge saved, Wago verified live). Roadmap edit run 44904947066.
- #chat 2026-11-21: 0xDAB tooltip over bar (ctx below) + FPS halves (investigation) dispatched; asked 0xDAB for version/when/HUD/addons/profiler number + screenshots of misaligned windows. Evil suggestion: micro menu + bag bar inside the data bar (feature request; data bar already has micro menu toggle; check bag bar).
- FPS: no Lua regression (report ~/.cache/kstyleui-evidence/fps-halves/REPORT.md). Asked 0xDAB for profiler macro + KstyleUI off/on FPS + Mac model + HUD style.
- Lee: crest jewels need polish (full ring glow at max, as his mockups). Worker polish-crest-jewels.md dispatched; show Lee GIFs before merge. Waiting on Lee's original mockup images.
- Baine PR #668 (/kstyle perf): fork CI skipped; ran checks on contrib/pr-668 run 44910584593; review ctx_02de2c880984. Replied in #chat.
- Merged #669 (Medallions party INSIDE crash). Hotfix v0.2.9.1 branch 7c466ef3 (v0.2.9 + #669 + notes incl Notes.lua); checks run 44910814337. On green: ff main, tag v0.2.9.1, mirror notes to staging (CHANGELOG/RELEASE_NOTES/Notes.lua/locales).
- #668 review posted to Baine (request changes). Offer: we push fixes if maintainer edits allowed.
- Merged #666 (GF r6). GF left: ~11 rows + Match Mode.
- v0.2.9.1 TAGGED (main ff 7c466ef3). Release watch bcz3ohoe2. Notes #670 merged.
- Merged #667 (tooltip clear). Hotfix v0.2.9.2 branch b0f255e5 (v0.2.9.1 + #667 + notes incl Notes.lua); checks 44913259326. On green: ff main, tag, mirror notes to staging (PR), reply to 0xDAB that the tooltip fix shipped.
- Baine (14:08): maintainer edits allowed, 'feel free to change any of my PRs'. Fix worker ctx_cd38a80ea7da pushes to Baine/KstyleUI feat/kstyle-perf + contrib/pr-668 CI. Standing: we may finish Baine's PRs ourselves.
- v0.2.9.1 RELEASED. v0.2.9.2 TAGGED (main ff b0f255e5); release watch b5uwr6w9z. Notes PR #672. After release: tell 0xDAB tooltip fix is out.
- #671 jewels polish: pips mismatch was render scene only (fixed). Awaiting Lee's look at GIFs before merge.
- Merged #668 (Baine /kstyle perf) -> v0.2.10. Told Baine.
- v0.2.9.2 RELEASED (rerun after Mac CPU flake). Notes #672 merged. Told 0xDAB.
- 0xDAB 15:13: profiler shows all addons 0.4%, fps 102; KstyleUI Lua not the cause. Asked for FPS KstyleUI off/on/Motion Off + HUD style + Mac.
- GPU/draw-cost research+cuts dispatched (perf-gpu-draw-cost.md). Issue #484 answered/fixed earlier -> close with note.
- #673 perf (hidden nine-slice centres, -20% drawn area) in review ctx_20bd5d210baf. Medallions switches (vignette, ambient hub) dispatched. Atlas of chrome textures = owner decision (big).
- Merged #673 (hollow nine-slice centres hidden, pixel-identical; -20% drawn area). Style.Pieces in GroupFrames/Style.lua now unused -> tidy later. Perf: candidate for a hotfix? It's perf not bug -> ships v0.2.10.
- Merged #674 (Medallions vignette + ambient hub switches).
- v0.2.10 notes worker ctx_297ad8050e0a. Contents: #673 draw cut, #674 switches, #668 /kstyle perf (credit Baine), #666 GF r6. Then staging Mac green -> commit-tree main -> tag v0.2.10 -> roadmap/store refresh if needed. Jewel polish #671 waits for Lee.
- #675 v0.2.10 notes merged; staging 3cb4b699, Mac run 44936035908. On green: main := commit-tree staging tree -p origin/main -p origin/staging; tag v0.2.10; watch release; update roadmap (v0.2.10 out); store page: add /kstyle perf + switches if worth it.
- v0.2.10 RELEASED. Roadmap #676 merged + post edited. Told 0xDAB.
- Lee approved crest jewels (#671); rebased, idle-draw guard fix dispatched. Lee: class-themed animated resource pips (rogue themed etc.) dispatched; Taildrop GIFs to iphone182 for review.
- Lee: when jewels polish + class pips are done, render and post a 'what we're working on' preview with GIFs in #chat.
- Baine FR (19:26 #chat): BM hunter Summon Hawk (spell 1293241, 2 active, 18s) on the crest. Research+mockup ctx above; then post mockup in #chat asking Baine for feedback.
- Merged #671 (crest jewel polish, approved by Lee) -> v0.2.11.
- Posted hawk perch concept (B) in #chat asking Baine for feedback (Lee picked B).
- Lee 'build it and ship it' -> hawk perch (B) becomes a real PR (specs/build-hawk-perch.md) via same worker ctx_497c71a0f26a. Credit Baine.
- #679 hawk perches green (run 44946198302); review dispatched; GIFs Taildropped to Lee. Author dispatch ctx_497c71a0f26a kept for fixpr.
- Lee rejected rogue dagger pips WIP (not enough polish/flair vs hawk). Told pips worker: concepts first (2-3 stills), owner picks, then build; hawk #679 is the benchmark.
- Rogue pip concepts A sockets / B crown of blades / C blade rack sent to Lee (concepts-rogue-all.png); worker waits on pick.
- #679 review ISSUES (breath loop after secret expiry, flyout cancels flare, warrior registers motion cb, fixture keeps expired hawks); fixpr dispatched; reviewer + author workers tidied.
- Lee picked rogue pips concept B (Crown of blades); worker building; druid concepts next.
- Baine asked about 2 green dots above player health = resting Zz too tiny. Replied in #chat (Lee's tone). Fix dispatched (bug-resting-zz-tiny.md) -> hotfix.
- Merged #679 (hawk perches, credit Baine) -> v0.2.11. In-game check: GetTotemInfo(2/3) shows hawks, no combat errors.
- Lee: post jewel polish GIFs for ALL classes. Posted rogue/paladin/warlock (v0.2.11 preview) in #chat; druid render ctx_1b3f238e0258 -> post when done.
- Lee: class-themed pips must cover ALL class resources (rogue, cat druid, paladin holy power, warlock shards) in the crown family; worker told: concept sheet for druid/paladin/warlock next. (Jewel GIFs posted earlier were a misread, but still valid v0.2.11 preview.)
- #681 resting Zz (cut to '...' because box too small) green; review dispatched. Note: Zz over player name at 5120x1440 Frames (existing overlap) -> fold into fix round.
- Lee loves crown of blades: posted rogue crown GIFs (Medallions + Frames) in #chat. Research crowns for every other class (stack-like resources) dispatched (research-class-crowns.md).
- #681 review: PvP timer moved 0.9u; fixpr ctx_60955d65205c (+ Zz over name at 5120 Frames). Tidied review/author.
- Lee: crowns approved; keep full size; cast bars move onto player/target frames (new PR, medallions-castbars-on-frames.md); druid mana option b.
- TODO when #678 crowns + cast-bars PR merged: render final GIFs per class (rogue/druid/paladin/warlock, Medallions 1080 + Frames) from staging with cast bars on frames, post in #chat (dpost). Lee asked.
- Lee: release v0.2.11 now with everything merged + Baine Zygor #677 (Lee tested in game). contrib/pr-677 CI 44953150442; notes worker dispatched (notes-0211.md).
- Zygor #677 update incoming; holding merge; watcher b4c0dnbvm on new head.
- Zygor final = #682 (korallis branch, CI native, run 44953431139). Merge on green, close #677 thanking Baine. Notes worker told.
- Merged #681 (resting Zz) -> rides in v0.2.11 (no separate hotfix). Notes worker told.
- Lee: speed up release. Plan: tag v0.2.11 right after notes PR merges with hosted CI green (skip waiting for staging Mac run); release.yml runs its own Mac gates. Offered moving release to hosted runners as separate change.
- Research: Forever has NO HolyPower/SoulShards power types -> paladin/warlock jewels+crowns never show in game. Pips worker holds pal/lock; research follow-up for replacements (warlock soul shard items?). Crowns sheet for other classes sent to Lee.
- Posted druid jewel GIF + correction (no holy power/soul shards on Forever) in #chat.
- Notes PR #684 (9269817a9) CI 44954328431. Paladin: Vengeance 20050 (Ret) / Reckoning (Prot); Warlock: soul shard items GetItemCount(6265). SlabJewels HolyPower/SoulShards reads need replacing.
- Merged #682 Zygor; closed #677 with thanks. #683 hotfix included in v0.2.11; notes updated 8b3b26f35.
- Lee: no paladin/warlock crowns (dropped permanently).
- Lee approved crowns: warrior/priest/shaman/mage/bear druid/hunter arrows. build-class-crowns.md dispatched (stacked on #678).
- Lee: druid post showed old jewel pips, wants approved claws GIF posted. Asked pips worker to send druid claws GIF first; post on arrival.
- #680 merged (worldmap taint) -> v0.2.11; notes 4f07219f8. Posted druid claws GIF in #chat.
- #686 cast bars on frames green; review dispatched; contact sheet sent to Lee. Author ctx_4a70b3be5d06 kept for fixpr.
- Release v0.2.11 HOLD: waiting for Zygor jitter fix PR + Zygor perf (ms) fix PR from Lee's other machine; #683 memory fail (suggest pcall GetParent). Then notes update, tag.
- #686 review ISSUES (6: in-combat toggle loses casts, saved visibility, Plate casts above crest, bar width, spell icon toggle, +22% instr); fixpr dispatched.
- #685 merged by Lee with lint fail -> lint fix PR #687. Notes fb07ded2 has #685 line. #683 pcall fix 491624a81 CI running.
- #688 cooldown secret text -> v0.2.11; notes 5c8f8dec.
- Merged #687 (lint fix) and #683 (pcall memory fix; lua green, lint red only from staging zygor test). Waiting #688 + #684 CI, then merge, main, tag v0.2.11.
- #678 crowns (rogue+cat druid) green f3dbf7c00; review dispatched. Merge after #686 (cast bars) and review.
- v0.2.11 TAGGED (main 427be14f4). Release run 44959558342 (watch b96kq2sec). After: tell Baine in #chat, roadmap update, store pages refresh (Zygor).
- #678 review ISSUES (off-state 3489 px diff, secret truth tests, resources vanish, settings ignored, motion, frame retention); fixpr dispatched.
- Merged #686 (cast bars on frames) -> next release (v0.2.12). Crowns #678 fix round running.
- v0.2.11 RELEASED. Told Baine in #chat. TODO: roadmap update, store pages refresh (Zygor).
- v0.2.11 RELEASED (run 44959558342). Told Baine (deleted 2 duplicate posts). Store+roadmap refresh dispatched (docs-store-0211.md); then paste CurseForge/Wago + roadmap Discord post.
- Lee: shaman totem bar (Blizzard MultiCastActionBarFrame, unstyled/unplaced) needs ultra polish. Design research+concepts dispatched (design-shaman-totem-bar.md).
- Lee: shaman package = totem bar + stance/form bar (Ghost Wolf), 'true love'. Worker told.
- Merged #690 (store/roadmap). Follow-up: re-render warlock crest marketing crops (same names). Next: paste CurseForge/Wago descriptions + roadmap Discord post.
- Store pages pasted (CurseForge + Wago verified after reload; Zygor in, holy power out). Roadmap post edited (run 44963280590, msg 1573443520474120352).
- Shaman design delivered: A Elemental Sill / B Spirit Poles (rec) / C Totem Pole; sent to Lee; 5 decisions pending.
- Merged #678 (rogue + cat druid crowns) -> v0.2.12. Crowns worker told to rebase.
- Lee picked shaman B Spirit Poles (defaults: earth,fire,water,air; earth green; smaller socket spires; right-click Call=Recall). Build dispatched; crowns worker drops shaman.
- #691 marketing crops rendered pre-crowns; asked to rebase + re-render with crown.
- Lee bug: cooldowns show with Cooldown Manager disabled (shaman, Medallions). Hotfix worker dispatched.
- Lee: remove duplicate player-frame buffs in Medallions (dispatched); Lightning Shield charges on crest like hawks (concepts first, coordinate with Spirit Poles) dispatched.
- Merged #691 (crown of blades marketing crops) -> stores update at v0.2.12.
- Lightning Shield concepts A Storm Orbs (rec) / B Charged Ring sent to Lee; worker waits.
- #692 cooldowns CVar off fix green; review dispatched; then hotfix v0.2.11.1.
- Lee picked Lightning Shield A Storm Orbs; building.
- Lee: remove Frames + Orbs entirely (Medallions only; migration moves profiles). Dispatched remove-frames-orbs.md; told Spirit Poles, Lightning Shield, crowns workers to skip Frames/Orbs.
- #692 review ISSUES (layout movers absent on cold login with CVar off, account hint consumed, 4K evidence) -> fixpr. #693 player buffs off green -> review.
- #693 review: needs versioned migration (import/SV with old true) + 2560/5120 evidence -> fixpr.
- #694 Spirit Poles green; review dispatched; GIF+crops to Lee. Known: open fan overlaps the cooldown row above the crest (fix in fix round).
- Merged #692 (afbdbc95c). Hotfix v0.2.11.1 worker dispatched (hotfix-02111.md).
- #694 review ISSUES (Recall can summon, dismiss modifier, missed updates, closed fans repaint 40, parity pairs differ) + fan overlap -> fixpr ctx_8104ff52e108.
- Frames/Orbs removal: follow-ups after merge = (1) forged ornaments + tools/tests, (2) non-slab UF forms + Style dropdown, (3) card-material frames/grain.
- Merged #693 (player buffs off, migration 44) -> v0.2.12.
- #689 crowns (warrior/priest/mage/bear/hunter) green; review dispatched; GIFs to Lee. Frames/Orbs removal: helpers A/B/C dispatched.
- Posted 5 crown GIFs (warrior/priest/mage/bear/hunter) in #chat. v0.2.11.1 TAGGED (main 58856c419); release run 44971670162 (watch b2tqk0gf9). Merge notes #696 after.
- #689 review ISSUES (bear form first shift 0/11 feeds, spellbook changes interrupt rogue gains, stale ring colours, missing bar API claims seat) -> fixpr.
- v0.2.11.1 RELEASED (run 44971670162). Notes #696 merged.
- Helper D (ctx_11bc392c63f6) dispatched for 24 UF tests from the lead's share.
- Merged #694 Spirit Poles -> v0.2.12. Follow-up polish (fan unfold, flicker, all-four ring, 82% icon) sent to ctx_8104ff52e108.
- Helper E (ctx_19910c1ea966) dispatched for #695.
- Helper D done (24/24). Possible real bug: Medallions target SIDE auras shift 22->18 with a TOP text bar (r4a-review check removed) -> investigate after #695. Lead must fix CastEffects.lua LF + 7 luacheck warnings.
- #698 Spirit Poles polish green; review dispatched; GIF to Lee.
- Helper F (ctx_48d49ab05f02) docs/pictures for #695.
- #698 review ISSUES (icon state after spell change, stale flicker callbacks, stale class colour, 4K pair diff) -> fixpr.
- Helper E done 28/28 (+ real Strip.lua overflow rebuild fix). Possible bugs for after #695: dock-to-rail values keep dock ink until change; Medallions raid tiles ignore auras.timers (also staging); Medallions LOOK overlay blocks turning off party medallions / raid names above.
- Merged #689 (warrior/priest/mage/bear/hunter crowns) -> v0.2.12. In-game: Sniper Shot charges as applications; aura end clears at once (accepted).
- Helper C done 66/66 (+5 Medallions per-call allocations fixed). Possible follow-ups (8 pinned Medallions limits) listed to lead. Python gallery_unitframes ellipsis failing pre-existing on branch.
- Merged #698 Spirit Poles polish -> v0.2.12.
- Helper F done (docs/pictures 851e48c6c). Lead owns AGENTS.md, verify/features/hud-styles.md, comments, Setup help, Style dropdown, gallery_unitframes python fail.
- #695 leftovers done (49f566fb2). Pre-existing Medallions bug: long unit name 'ELUNARA FROSTWEAVER' truncated in Options gallery unit frames (needs 114.1, has 95.3) -> follow-up fix after #695. test_render_gallery_scenes now honours guard_allow.tsv.
- Helper B done. 22 possible Medallions defects (8 confirmed on staging) saved at medallions-defects/helper-B-report.md -> follow-up after #695.
- #697 Storm Orbs green; review dispatched; GIF to Lee.
- LEE-5958 created for #695 pixel_allow growth; sent to lead + helper A.
- Helper A done (82/82). Possible bug: Tank damage+threat meters 88u off-screen at 3456x2234 (pre-existing) -> follow-up. #695 final CI next.
- #697 review ISSUES (restricted-build error, charge double count, stale combat counts, Motion Off animating, final bolt position, halo transitions, hot-path work) -> fixpr.
- #695 ready (net -12,375 lines, CI green, pixel-identical); review dispatched. Evidence copied to medallions-only/.
- Merged #697 Storm Orbs -> v0.2.12. In-game: 3-2-1 applications, strike event, /reload in combat.
- #695 review ISSUES (migration notice repeats in previews, retired keys in saved layouts/exports, scale cache oversized HUD, retired choices visible, 19 missing pixel pairs) -> lead fix round.
- Merged #695 (Medallions only). Dispatched: cleanup ornaments+materials, bugs layout (MacBook Tank meters, 3:2), bugs look overlay. Later batches: raid/party tiles, unit frames slab/previews, nameplates/bags/RestedXP/misc; follow-up 2 (UF forms/Style dropdown).
- Look overlay PR: UnitFrames per-mode aura defaults (rows/fan/both) left as follow-up.
- Staging Mac red: test-perf ActionBars pet cooldown + key press headroom (real, not load). Fix dispatched (fix-staging-perf-headroom.md).
- Layout bugs: ship Tank threat card width fix (MacBook meters, 3:2 cap) + bar 3; follow-up needs design decision: raid warnings lane at 3:2, boss box/debuff row, Edit Mode buff/bar spots, 3024x1964 loot feed vs pet bar.
- #699 look overlay (choices win) green, -39 lines; review dispatched.
- #701 dead ornaments+materials removed (-7.5k lines, 1.57 MB) green; review dispatched.
- #699 review ISSUES (raid power overlaps health, options 6px, slider, docs) -> fixpr ctx_515fa84f4182; UF per-mode keys stays follow-up.
- #700 perf headroom (cause #695 pet events rebuild slab) review dispatched. Locale test over Mac CPU -> split dispatched.
- #701 review: v45 imports fail (migration 45 edited) -> fixpr ctx_ff5977979906 with migration 46.
- #702 layout: option A (second data bar spot, loot feed nudge, Enabled key bug).
- Merged #700 (perf headroom). Staging still needs locale test split (ctx_21b311d7e415).
- Merged #703 (locale test split, Mac 9.2+12.2 s). Watching staging Mac run (bxxo9mgp4).
- Merged #699 (choices win over Medallions look; raid power room). Follow-ups: UF per-mode aura defaults; nameplate height on outline round-trip.
- Merged #701 (dead ornaments/materials, migration 46). Todo: docs/core-services.md row for v46 (tiny).
- Staging Mac 44990248483: only test-perf-frames UnitFrames UNIT_FLAGS 4.2x (<5x) under load 4.4. Watching newest staging run (bimvgs46k).
- Staging Mac GREEN at b7c5287b1 (run 44990646106). v0.2.12 after #702.
- #702 layout green; review dispatched. Then v0.2.12.
- v0.2.12 notes dispatched (notes-0212.md).
- #702 review: threat width 70u understated, loot cards shrink 7, bar 3 backing -> fixpr ctx_9db30bff16b3; deferrals stay.
- v0.2.12 notes #704 green (3b78ac47e). #702 lines under HTML comment markers: remove comments (if #702 merges) or lines (if not) before merging #704.
- Merged #702. Notes #704 markers removed (abab0985); waiting CI then merge, staging Mac green, then v0.2.12 commit-tree + tag + store/roadmap + Discord preview.
- #704 notes merged; staging 6bb6db85a Mac run 44995167318 (watch bs8je52mz). On green: commit-tree main, tag v0.2.12, release watch, store paste, roadmap, Discord preview of crowns/shaman.
- v0.2.12 TAGGED (main a43827371); release run 44995818963 (watch br5st11as). After: store paste, roadmap edit, #chat announce, memory.
- v0.2.12 RELEASED (run 44995818963). Stores pasted (CF + Wago verified). Roadmap PR #705. Announced in #chat.
- Roadmap #705 merged; Discord roadmap edited (run 44997150475).
- v0.2.13 batches dispatched: group tiles, unit frames. Pending: nameplates/bags/RestedXP/chat/ranks/databars misc batch; UF per-mode aura defaults; layout design decisions (3:2 warnings/boss/Edit Mode/3024x1964) await Lee.
- #706 unit frames settings green; review dispatched. Focus name at 2383x1540 still cuts (follow-up).
- #707 group tiles green; review dispatched.
- #706 review ISSUES -> fixpr ctx_5ec9edf87aa9 (ring bleed belongs to #707).
- #707 review ISSUES (compact party marker collisions, raid icons over previous member, ready check over boss slot, long names, role help) -> fixpr.
- #706: preview cast gap stays 4 (known limit); follow-up: Options Preview.Fit ignores tile rim, name sized before final Fit.
- Merged #706 (UF settings honoured; focus name fits at 2383x1540).
- Merged #707 (raid tiles/party rows honour settings). Next misc batch + UF per-mode defaults; Lee decision pending: 3:2 boss column/warnings.
- Misc Medallions bug batch dispatched.
- Misc batch: PR1 = nameplates/ranks/chat/databars + MeasureHeader opt 2; PR2 = RestedXP slot (Layouts.Story) + render ref positions + hub caption font.
- Lee bug: targeting a mob flashes all same-type nameplates (KstyleUI only). Hotfix worker dispatched.
- Plate flash = red selection circle under all same-type mobs on right-click; worker redirected to CVars/soft target/WorldFrame.
- #708 misc PR1 review dispatched. RestedXP guide slot at Auto (70 units vs 166 needed) needs owner design: guide takes the 186 quest column or stacks above quests.
- #708 review ISSUES (plate height transitions, render error) -> author fix round.
- Merged #708 (small fixes). #709 (hub caption, ref declarations, crest pixel) review dispatched. RestedXP slot = owner design.
- #709 review: test strictness + scope note -> author.
- Merged #709. v0.2.13 content: #706 #707 #708 #709. Pending owner: red circle tests, RestedXP slot design, 3:2 boss column.
- Merged #709. Hotfix v0.2.12.1 from staging (fixes only #706-#709): notes dispatched.
- #710 v0.2.12.1 notes merged; staging Mac run watch bvwx8qws2; on green: commit-tree main, tag v0.2.12.1.
- Staging Mac test-perf-frames UNIT_FLAGS 4.2x again (load 4-9). Rerun requested; fix dispatched (fix-unitflags-headroom.md).
- Rerun failed again (UNIT_FLAGS). v0.2.12.1 waits for ctx_ca4d953e53d9 fix.
- #711 UNIT_FLAGS (cause #695 repaint power contrast/reset ring on unchanged inputs) 17us on Mac mini; review dispatched. Then merge, staging green, tag v0.2.12.1.
- Merged #711 (UNIT_FLAGS 16us, 5.9x). Watching staging Mac for v0.2.12.1.
- v0.2.12.1 TAGGED (main 03a8b5fa0); release run 45019088007 (watch bpfjc82fe).
- Red circle: owner can't test; worker told to investigate statically and fix if strong evidence, else hypotheses + test plan.
- Lee: guides on the left + quests in story rail (dispatched); 3:2 = option A keep HUD pixels (dispatched). Note both touch Layouts.lua -> sequence merges.
- v0.2.12.1 release run finished (see output).
- v0.2.12.1 release run failed pixel-grid-16 CPU (33.86/33); rerun failed jobs; split dispatched.
- Red circle: no cause offline; plan at kstyleui-evidence/red-circle/REPORT.md (top hypothesis: game's quest unit circles, ShowQuestUnitCircles). Waiting on Lee's in-game test later.
- Guides left: TOPLEFT 278w above party; raid -> fallback to rail slot if cheap; quest card keeps its column.
- v0.2.12.1 RELEASED (rerun after pixel-grid-16 CPU).
- #712 3:2 warnings/Edit Mode green; asked author to keep 16:9 Healer warnings at 15% (542 lane) before review.
- #712 v2 (16:9 15%) green; review dispatched.
- #713 guides-left: approved Core/Profiles.lua guard for non-table profileKeys (latent login crash found by property test).
- Merged #714 (pixel grid 32 parts). Todo: docs/core-visuals.md says 'sixteen' pixel-grid files.
- #712 review ISSUES (anchor refresh, 2560 bars, 405 lookups) -> author.
- #713 guides left green; crops to Lee; review dispatched. README right-rail picture outdated (follow-up).
- #713 review ISSUES (Zygor over party 115u, RestedXP first objective offscreen in combat, Edit Mode Spread rect, descriptions) -> author; empty slot is approved.
- Merged #712 (3:2 warnings, Edit Mode room, boss debuff row; HUD unchanged).
- Merged #713 (guides top-left, quests on story rail, migration 47). Todo: README right-rail picture retake + core-visuals 'sixteen'.
- v0.2.13 prep: README rail pictures + notes dispatched.
- #716 README/store pictures retaken (guide on left); #715 v0.2.13 notes; waiting CI both (b2mrb64d2).
- Lee: redo README + store descriptions short, GIF highlight reel (crowns, storm orbs, rogue blades, poles, hawks, jewels), Lee's voice, no AI tells. Dispatched docs-readme-gif-redo.md.
- #715 notes green. Waiting b2mrb64d2 for #716, then merge both, staging Mac, tag v0.2.13.
- Lee: HOLD v0.2.13 tag until README/marketing GIF redo (ctx_96377fe46304) merges; then release with new store styling.
- Staging Mac green at 5b2f525bf (run 45029546924). v0.2.13 held for README/store redo.
- Lee: bring Frames back (Orbs stays gone), hold v0.2.13 for it. restore-frames.md dispatched; README worker told to include Frames.
- Lee: parallelise Frames restore; lead ctx_26bb030adc97 authorised to start its own helpers (suggested 5-way split).
- Lee: use hosted runners. Workers told no intermediate Mac runs. ci-release-reuse-tree dispatched (release reuses staging same-tree run).
- #717 Frames: core+U+H+P+D done; R Medallions 12/12 identical; A finishing. Cautioned on editing shipped migration 45.
- #718 README redo good; jewels GIF/caption wrongly paladin/warlock -> fix requested.
- #719 release proof same-tree reuse; docs line requested; review dispatched.
- #719 review: pagination + unresolved newer tree -> author.
- #718 all 9 classes back; review dispatched.
- #718 review: cache freshness, switch semantics, pacing; Frames claim kept (ships with #717); retake Frames still after #717.
- Merged #719 (release reuses same-tree staging run).
- #717 Frames restore green (hosted + Mac); review dispatched. Then notes Added line, #718 Frames retake, v0.2.13.
- #717 review ISSUES (migration loses Frames settings, style round trip overwrites Medallions customisations, sizing, ornament pairs) -> lead fix round.
- Lee: audit fights with other addons + redundant reloads (Zygor-style). Two-family audit dispatched; then fixes + guard test.
- Audit fights: muse ctx_cbb0e17d76de, grok ctx_807058cc87c6, claude ctx_4a0a67c10bc4 (released duplicate muse ctx_44384f8d7ffc on purpose).
- Audit scope extended: art (lazy create, hidden animations, redundant SetTexture) and triggers (events for off features/classes/style).
- Audit muse done: top RXP rail Restyle full Place (no unchanged key), ApplyFont always SetFont (Questie/RXP/Tracker), SetAlpha hush copies, minimap drawer re-place, SPELL_UPDATE_COOLDOWN full sweep. Waiting grok + claude.
- Audit grok done: Zygor ShowTraveling writes colour/alpha every frame, 0.01s tab timer 874 instr/tick, SPELL_UPDATE_COOLDOWN full walk 6815 instr, minimap drawer LibDBIcon re-anchor, vignette off still on UNIT_HEALTH. Waiting claude.
- Audit fixes dispatched in 4 areas: core/RXP + fight guard test, Zygor, actionbars/cooldowns, minimap/triggers.
- Merged #717 Frames restore. Told #718 + 4 fight workers to rebase. Next: #718 Frames retake, notes Frames line, v0.2.13.
- Merged #721 (Frames in v0.2.13 notes). v0.2.13 waits on #718 renders.
- #720 Zygor per-frame work removed (52k->6k instr/100 ticks; 240->0 writes); review dispatched.
- #720 review ISSUES (arrow ownership swallows setters, pooled titles, disabled scan) -> author.
- #722 actionbars/cooldowns per-change (form 30k->2.6k, sweep 6.5k->3k) review dispatched. Leftovers: crown pips per form, slab crest repaint per loading screen, PLAYER_TARGET_CHANGED jewel/pet rewrites, Cooldowns Viewers alpha hush.
- #722 review ISSUES (form counts/borders, override cooldown, pet stance cd, consumables, slab textures) -> author.
- #723 minimap/vignette/triggers idle work removed (8 fixes); review dispatched.
- #723 review ISSUES (drawer icon size/alignment regression, secret scale compare, anchors, auras queries when off) -> author.
- Merged #720 (Zygor per-frame work gone).
- #724 core/RXP fights + test-perf-fights guard (fails on staging 876 fights, on pre-#685 Zygor); review dispatched.
- #724 review ISSUES (52 rect diff, reanchor/folded rows, secret geometry, detector coverage, Questie off) -> author.
- Merged #722 (action bars/cooldowns per-change).
- Merged #718 README/store redo. Next: add perf lines (#720/#722) to v0.2.13 notes, staging Mac, tag v0.2.13, paste stores.
- Merged #725. Watching staging Mac for v0.2.13 tag.
- Merged #723 (minimap/triggers idle work) after the v0.2.13 tested commit; ships next.
- v0.2.13 TAGGED (main f5eb6c1b9 from tested 2f0fa8cd8); release 45063070060 (watch b5ue6noq3). After: paste new store page, roadmap, #chat.
- v0.2.13 RELEASED in 8 min (reused staging run 45061914466). Stores pasted (CF+Wago verified, GIFs 200). Roadmap PR #726. #chat announced.
- Store summaries fixed (CF+Wago). Merged #724 fights + guard, #726 roadmap; roadmap post edit started. Next: v0.2.13.1 hotfix (#723+#724) notes.
- Lee: everything fast, parallel. Dispatched 6: perf-round2, perf-actionbars-leftovers, uf-aura-permode-defaults, options-preview-fit, GF parity r7, Auras r3 (consumable count/low-mana).
- Store gallery swap dispatched (browser task).
- #727 v0.2.13.1 notes merged (810b8fcb1); staging Mac watch blp0duz26; tag that exact commit when green.
- Store galleries swapped (CF 8, Wago 8).
- v0.2.13.1 TAGGED (main 427675b32); release 45067195843.
- v0.2.13.1 release finished (see output).
- #728 Auras r3 (flask reminder, low mana at ready check) green; review dispatched.
- #728 review ISSUES -> author.
- #730 UF aura per-mode keys (migration 48) green; review dispatched.
- #729 actionbar leftovers green; review dispatched.
- #730 review ISSUES (combined-filter count overwrite, Focus stale copies) -> author.
- #731 options preview fit (root cause float-noise OnSizeChanged) green; review dispatched.
- #729 review ISSUES (stale glow on toggle, power event cost up) -> author.
- #732 GF r7 (10 rows) green; review dispatched. Next round: Anchor, Show on Bottom, Match Mode; FrameSort flagged not provable, HoverCast breaks consistency.
- #731 review ISSUES (rim 0.218px, name grid 0.127px, Frames cast outline lost at 1440p) -> author.
- #733 perf round 2 green; review dispatched.
- Merged #728 (flask reminder, low mana at ready checks).
- #732 review ISSUES (defaults on upgrade, pets, click overlap, stale state, 80 restyles) -> author + remaining 3 rows.
- #733 review ISSUES (restricted reads, reparent memo, clamp fallbacks, minimap resize) -> author.
- Merged #729 (actionbar leftovers).
- Merged #730 (UF aura per-mode, migration 48).
- Merged #733 (perf round 2).
- Merged #731 (Options preview fit + StatusBar edge float slack).
- v0.2.14 notes dispatched (#732 lines behind marker).
- Merged #732 GF r7. Next round: FrameSort, Anchor, Show on Bottom, Match Mode. Notes told.
- #734 v0.2.14 notes merged (f43a44e21); staging Mac watch bhjl230mz; tag that commit when green.
- v0.2.14 TAGGED (main 22a2f1cd8); release 45075888335.
- v0.2.14 RELEASED; #chat announced; roadmap PR opened.
- Roadmap #735 merged; Discord roadmap edited.
- #736 GF r8 (Show on Bottom, Anchor, FrameSort; Match Mode not possible) green; review dispatched. Group frames table complete.
- #736 review ISSUES -> author.
- Merged #736 GF r8 (group frames table complete).
- v0.2.15 notes dispatched.
- #737 v0.2.15 notes merged (97e58b230); staging Mac watch bo4955ilv; tag when green.
- v0.2.15 TAGGED (main 281f4d9cd); release 45083336928.
- v0.2.15 RELEASED; #chat announced.
- v0.3.0 polish: 8 workers dispatched (type-voice, glass-bars, rest-fade, casts, medallions-finish, options-layout, first-run, health).
- v0.3.1 explorer: 2 workers dispatched (services-quests, reveal-travel).
- #738 load notice + About Status green; review dispatched.
- #740 nearest services + quest routing green; review dispatched.
- #738 review ISSUES (privacy in report, lost notices, combat Enter, scope) -> author.
- #742 reveal + travel stops green; review dispatched.
- #740 review ISSUES (missed visits before map open, nearest picks, stale off state, per-frame redraw, quest feedback) -> author.
- #739 first run (big pictures, Looks) green; review dispatched with size check.
- #743 Medallions caps + calm crest green; review dispatched.
- #745 type voice + readable text green; review dispatched (budget headroom check).
- #742 review ISSUES (tram, hearth stale/locale, fallbacks, reveal overhead, solve cost, Frames shots) -> author.
- #739 review ISSUES (Readable shrinks names, setup overwrites, previews keep textures, PNG dupes) -> author.
- #743 review ISSUES (caps too subtle, detached cast bar, wake cost, sheen race, regions) -> author.
- #744 clean screen at rest green; review dispatched.
- #745 review ISSUES (ignored font picks, button shadows, hidden halo calls, budgets) -> author.
- #747 casts by caster + interrupt states green; review dispatched.
- Merged #738 (load notice + About Status).
- #747 review ISSUES (Frames focus cues, secret channel interrupts, GCD readiness, hidden plate work, alignment) -> author.
- #744 review ISSUES (low health/hover fade, Layout Mode wake, overwrites other fades, disabled hooks) -> author.
- #741 Options/Layout polish green; review dispatched.
- Merged #740 (nearest services + quest routing).
- #741 review ISSUES (Reset after exit, search/preview parity, hidden map work, rect reads) -> author.
- Merged #743 (Medallions caps + calm crest); caps crop shown to Lee.
- Merged #742 (map reveal + travel stops).
- Merged #739 (first run pictures BLP 2.1 MB + Looks). In-game: check setup BLPs.
- #746 lit glass bars green; review dispatched (region ceiling raise flagged).
- Merged #747 (casts by caster + interrupt states).
- #746 review ISSUES (restore 172 regions, XP glass orientation, tooltip preview, off parity 3649px) -> author.
- Merged #744 (clean screen at rest).
- Merged #745 (type voice + readable text). Flaky: test-widgets-kit chrome-setter alloc on hosted Linux (seen on #745, #746).
- widgets-kit flake fix dispatched.
- Merged #741 (Options search/previews/motion, Layout Mode).
- Merged #748 (widgets-kit flake: stack slot reserved).
- Merged #746 (lit glass bars). Follow-ups: skinned Blizzard bars glass; check-package.sh:69 pipefail SIGPIPE race.
- v0.3.0 notes dispatched.
- check-package SIGPIPE fix dispatched.
- Merged #749 (check-package SIGPIPE).
- #750 v0.3.0 notes merged (1ca7b747e49a13207ada8a273e6555e9f3fe20bb); watch staging Mac run.
- Staging Mac red: test-options-search 22.05 CPU s; fix dispatched. Release waits.
- Merged #751 (options search test 6.75s). MacBook runner on battery 1%: shard 2 CPU failures are throttling.
- v0.3.0 TAGGED (main 1e82cd8ab) from staging b35b62b87.
- v0.3.0 README/store GIF refresh dispatched.
- v0.3.0 RELEASED (run 45121171074).
- v0.3.0 #chat announced.
- Roadmap #752 opened. v0.3.1 dispatched: item levels, glass on skinned bars.
- Roadmap #752 merged; Discord roadmap edit run 45123651822.
- #754 glass on skinned bars green; review dispatched.
- #755 README/store green; map.gif reframe asked. Route-step names + raid tile bug fix dispatched.
- #753 item levels (character+inspect; bags existed) green; review dispatched.
- #754 review ISSUES (textures in combat on protected resize, hidden page allocs, strip hushes kept, tracker assert vacuous) -> author.
- #753 review ISSUES (inspect ignores toggle, hidden slot work, secret guards, bag/char palettes differ) -> author.
- Merged #755 (README/store v0.3.0 GIFs). Store paste waits for next release (raw main URLs).
- Merged #753 (item levels).
- #756 route step names + raid dispel wash opaque (real bug) green; review dispatched.
- #756 review ISSUES (quest/hearth labels end in 'to', exact-node service name, cold solve 6.7x cost, wash alpha via colorRGB) -> author.
- Merged #754 (glass on skinned bars). Follow-up: loot-roll scene 14 off-grid regions vs 12 allowed on staging.
- Merged #756 (route step names, raid dispel wash). In-game: wash alpha check.
- v0.3.1 notes dispatched.
- #757 v0.3.1 notes merged (5fb2142a4a0fd99db7bd418b42862fc947de14d6); watch staging Mac.
- Lee: use GitHub runners. Dispatched ci-hosted-staging-release (staging+release gate on ubuntu, Macs non-blocking).
- v0.3.1 TAGGED (main 23d10b561).
- v0.3.1 RELEASED (run 45138147488).
- v0.3.1 store descriptions pasted (CF+Wago), #chat announced.
- Dispatched store gallery 09-11, v0.3.2 gamepad.
- #758 hosted CI gate green; leftovers to author; review dispatched.
- Roadmap #759 merged; Discord roadmap updated.
- #758 review ISSUES (Pillow after publish, reuse needs lint downloads, vacuous regression) -> author.
- Galleries at 11 on both stores. #760 caption fix; CF caption update dispatched.
- Merged #758: staging+release gated on GitHub-hosted runners; Macs non-blocking (mac-budgets.yml).
- Merged #760 (CF captions).
- Lee: totem fan has no background in game. Fix dispatched (fix-totem-fan-background).
- First hosted staging run green (ad2f1884b, 8 ubuntu shards).
- CF captions 10/11 saved live.
- Lee in game v0.3.1: setup Welcome page blank. Hotfix dispatched.
- #761 gamepad green; review dispatched.
- Lee: consumables default size 26 spacing 0. Dispatched.
- #761 review ISSUES (keyboard shows pad glyphs, paddle markup, chord overflow, disabled scans, step 2 size) -> author.
- Lee: party frames hard to read (tiny at 5120, '10...' percent, cut names, pale missing health). Dispatched.
- #762 totem fan forged backing green; review dispatched.
- Lee: Medallions unit frames don't fit / not polished. Polish pass dispatched.
- Lee: polish = tiny details. Memory + review template polish check added. Polish detail audit dispatched on 3 families.
- #763 consumables 26/0 green; review dispatched.
- #762 review ISSUES (Frames fan covers spire, closed row changes, steel lip opacity, line culling) -> author.
- #764 setup page alpha safe fix green; dropdown/preview extension asked; review dispatched.
- Merged #761 (gamepad glyphs + Controls).
- Lee: more crest tracking for every class. Design workers dispatched (melee, ranged, healers); concepts to Lee for approval.
- #763 review ISSUES (old -0.5 spacing import fails, detached saved bar overlaps bar 2, vacuous size test, README says 19) -> author.
- Polish audit #1 (40 rows): party/UF/totem rows forwarded to in-flight workers; batches dispatched: meters, chat-bags-tips, plates-bars-map, options-setup.
- #762 #38 by design. #764 review ISSUES (f097 broke shards, dropdown jump, secret alpha, handles) -> author: revert f097, keep narrow.
- Lee approved all melee crest trackers ('add all'). Build dispatched.
- Polish audit A (23 rows) routed to batches; new batch skins-guides dispatched.
- Lee approved all ranged + healer crest trackers. Builds dispatched (share melee helper).
- crest builds: melee ctx_84afd76f826f (helper owner), ranged ctx_c85277db22ff, healers ctx_6b231e178299. Forward helper branch when melee replies.
- Released melee design + 2 audit workers. Beast heavily loaded (python gate 76 fails from 0xC0000142 under load).
- Polish audit B (36 rows, overwrote audit-polish-muse; copied to -b) routed to batch workers.
- Merged #762 (totem fan forged backing). Open: Medallions arc covers spires while open (transient, accepted); in-game fan check.
- Merged #764 (setup/Options page-only alpha fix). Follow-up: dropdowns/previews; root cause.
- Merged #763 (consumables 26/0). Next: v0.3.2 notes + release (gamepad #761, totem fan #762, setup #764, consumables #763).
- v0.3.2 notes dispatched.
- Crest helper pushed (korallis/melee-crest-trackers 18bab92b3); forwarded to ranged+healers.
- Ranged designer released; notes sent to ranged builder.
- #766 v0.3.2 notes merged (fdf8a1972273b2e046b8b67bbaf544361f483404); watch hosted staging run.
- v0.3.2 TAGGED.
- v0.3.2 RELEASED (run 45173577246); #chat announced.
- Roadmap #770 merged; Discord roadmap updated.
- #765 party readability green; review dispatched (dismissed rows flagged).
- Lee: add major cooldowns/enhancements for every class (shared cooldown rim in helper); hunter sting any + Rapid Fire rim. Sent to 3 crest builders.
- #769 meters polish green; review dispatched.
- Crest: one SlabTrackers lifecycle (melee owns); registration API + Frames row above stance bar requested; healers/ranged to register.
- Lee: bears + maximise crests. Full crest per form/stance/spec rule sent to all 3 crest builders.
- Crest preview posted in #chat (intro + 9 classes, GIF + sheet each).
- Lee: full research per class/spec (incl tank/healer) for complete crests. 3 research workers dispatched; results to builders.
- #765 review ISSUES (warm size switch HUD scale, buff anchor moves, raid names vanish, preview, backing, 1080) -> author.
- #772 Medallions UF fitted slabs green; review dispatched.
- #769 review ISSUES (overlapping names/icons, corrupted markup, restore fails, redundant writes, threat card expands) -> author.
- Crest registration API pushed e4333eb4a; forwarded.
- #772 review ISSUES (orphaned docking arms, icons straddling borders, restricted scale compare, heal tint, cast clearance, contrast, no-tween) -> author.
- Melee complete-crest research done; additions + bugs sent to melee builder.
- Ranged complete-crest research done; additions to ranged builder; topGem/pips/shared families to helper owner.
- #767 polish D green; review dispatched (17 'not real' rows to verify).
- Healers complete-crest research done; additions to healer builder.
- #768 polish C green; review dispatched. Follow-up: A3 UF player aura row, A9 bars 3/4 '-' hotkey.
- #773 polish E green; review dispatched.
- #767 review ISSUES (9 of 17 dismissals overturned, drawer/travel regressions, vehicle refresh overhead, threat/skull collision, world map fixture, stray XP change) -> author.
- #773 review ISSUES (arrow ownership, tracker resize, 2 overlaps, fixture) -> author. NEW: RestedXP 4.11.39 fails the skin entry check (pre-existing) -> hotfix task dispatched.
- Merged #769 (meters polish).
- #768 review ISSUES (restricted shopping tooltip level throws, honour controls overridden, preview overlap, bag countdown restore) -> author. #774 polish B open.
- Merged #765 (party readability). Owner call: 16:9 percent text size.
- Lee chose A: 16:9 party percent text stays its size (names keep 12 letters).
- #774 polish B green; review dispatched.
- #774 review ISSUES (Target preview steals the live level-up effects anchor, microtype, blank badge, tween cues, translated row drift, overbroad guard rule, clipped footer) -> author.
- Merged #767 (polish D). Follow-up rows needing other files: #13, #16 column, #17/B#28, A#2, A#13, B#5, B#18 stack count.
- Polish batch F (leftover real rows) dispatched.
- Merged #772 (Medallions UF fitted slabs, rivets).
- Merged #773 (polish E). RestedXP hotfix told to rebase.
- #775 RestedXP 4.11.39 hotfix green; review dispatched.
- #775 review ISSUES (scale setter dislodges docked chip, redraws fail the fight guard, standalone renderer crash) -> author.
- Merged #774 (polish B Options/setup).
- #771 healer crests green, evidence complete; review dispatched. 3 shared defects -> melee owner.
- Big #chat post: everything since v0.3.2 (7 crest GIFs + UF/party/meters before-after).
- #771 review ISSUES (cat form overlaps combo jewel, Frames loses charges/imbues, enchant timers accumulate, form/cooldown states) -> healer worker ctx_be667a8e1cc1.
- Merged #768 (polish C). Follow-up: C35 expiring-timer red (Core Duration.ExpiringColor).
- #chat: merged-so-far update posted.
- #777 polish F green; review dispatched. Owner decision: A#2 tracked-buff row slot above an empty utility row.
- #776 melee crests + shared system green, evidence complete; review dispatched.
- #777 review ISSUES (minimap buttons cross rim / collide with drawer and slider, stack count hits border, action-bar glow opt-out lost, drawer and glow need a tween) -> author.
- Merged #775 (RestedXP 4.11.39 hotfix).
- v0.3.3 = polish + RestedXP fix (crests -> v0.3.4). Notes dispatched.
- #776 review ISSUES (15 incl. combat-secret truth test, aura feeds survive switch-off, Frames jewels, stale icons) -> melee worker.
- #778 ranged crests green (stacked on #776); review dispatched. Note: soul wisps faint over the emblem.
