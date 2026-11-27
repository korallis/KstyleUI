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

- [ ] Follow [Check and deliver](https://github.com/korallis/KstyleUI/blob/staging/AGENTS.md#check-and-deliver): run `bash scripts/gate.sh` once with `PR_TITLE`, `PR_BODY_FILE` and `PR_LABELS` before pushing, then wait for `checks` and `pr-rules` to pass on the newest commit.
- [ ] One independent review of the diff against `origin/staging` by the latest GPT Sol model
