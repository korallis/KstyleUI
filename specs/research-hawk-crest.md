# Task: research + mockup — Beast Mastery hawk tracker on the Medallions crest (no PR yet)

Feature request from contributor Baine (Discord #chat, 2026-11-21): "would love to see my active hawk charges as BM hunter somehow (https://www.wowhead.com/forever/spell=1293241/summon-hawk)", "maybe kind of like combo points? or two half circles (one should aim to have two active)". Summon Hawk (Forever spell 1293241): dive-bombs the target and keeps attacking for 18 sec; only 2 hawks can be active at once; shares its cooldown with Arcane Shot. The owner wants "something cool based around the crest" and a mockup posted in chat for Baine's feedback.

**1. Research what is possible on Forever (cite file:line at 9dc84f0 and the client's own data if you can find it under `~/.cache`):**
- How the client exposes active hawks: a player buff/aura (and is it secret in combat? `C_Secrets`/`SecretWhenUnitAuraRestricted`), a totem/guardian slot (`GetTotemInfo`, `C_` guardian APIs), pet info, or only the player's own cast (`UNIT_SPELLCAST_SUCCEEDED` for spell 1293241; the player's own casts are not secret on Forever, others' are). Which gives a reliable count and remaining time, including the "oldest hawk is replaced when you summon a third" rule, death/despawn, leaving combat, and talents that change the 18 s.
- Whether `C_Spell`/DB2 confirm the spell ID, duration and the 2-hawk cap.
- Combat-lockdown or taint limits for showing it on the crest.

**2. Design (one forged look; read docs/medallions.md, docs/medallions-effects.md; match the approved crest jewels in PR #671):** propose 2-3 crest-based concepts, e.g. (a) two half-circle arcs hugging the crest ring (left and right), each a hawk that drains clockwise over 18 s with a talon/feather sigil and a dive flare when summoned; (b) two hawk sigils perched on the ring's shoulders with a draining ring under each; (c) Baine's combo-point idea as two hawk-feather pips. Prefer the one that reads instantly in combat and stays consistent with the jewels (gilt settings, hunter-green/amber hues from tokens).

**3. Mockup**: build the chosen concept as a scene-only prototype in your worktree (no PR; it may be quick code behind a render switch) and render animated GIFs over real game backdrops (`~/.cache/kstyleui-backdrops`), Medallions HUD, hunter, 1920x1080 (crop to the crest area so it reads on a phone): 0 → 1 hawk → 2 hawks draining → one expires → resummon replacing the oldest. Also one still per concept so the owner can compare. You may use Higgsfield (installed `higgsfield` CLI, see the higgsfield-generate skill) for art if it helps, keeping the forged look; no AI credit lines.

**Deliver**: `C:/Users/leeba/.cache/kstyleui-evidence/hawk-crest/REPORT.md` (findings with sources: what is detectable and how reliably, recommended concept, risks), the GIFs and stills in that folder, and a one-paragraph player-facing description the coordinator can post. No PR, do not merge or post anything.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report the verdict (feasible? how?) and the file list.
