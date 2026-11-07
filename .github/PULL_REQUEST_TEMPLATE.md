<!-- Title: type(scope): summary, for example "feat(minimap): add the square minimap". -->

## Summary

<!-- What this pull request changes and why, in two or three sentences. -->

## Changelog

<!--
One line a player reads, starting "Added:", "Changed:" or "Fixed:".
A pull request that changes only tooling or docs takes the "no changelog" label instead.
A change to a TOC "## Version" line or to CODE_BUILD also needs the "release" label.
-->

## In-game checks

<!-- One step per line that the owner runs in game to confirm this change. Write "None" for tooling and docs. -->

- [ ]
- [ ] Release candidates only: repeat the checks above after `/console addonCombatRestrictionsForced 1`, `/console addonEncounterRestrictionsForced 1`, `/console addonMapRestrictionsForced 1`, `/console addonChatRestrictionsForced 1` and `/console taintLog 1`.

## Checklist

- [ ] `python3 Tools/dev/crlf.py`
- [ ] `pre-commit run --all-files`
- [ ] `LUA=luajit bash Tools/regression/run-all.sh`
- [ ] `python3 -m unittest discover -s Tools/tests`
- [ ] `cr review --agent`: critical and major findings fixed, at most two rounds
- [ ] `/codex:review`: one cross-family review
