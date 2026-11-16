# Verification feature map

This folder seeds the top verification journeys for KstyleUI. [The feature map](../../docs/feature-map.md) stays canonical. It lists every player-facing feature with its settings place, code path, regression files and render scene. These files only add the journey view: what the player sees, how to reach it, how to drive it, and what proves it works.

- [HUD styles](hud-styles.md): Frames, Orbs and Medallions, the style switch, the medallion slabs and the crest hub.
- [Layouts and screens](layouts-and-screens.md): the DPS, Tank and Healer layouts, screen size, and the ultrawide centred and spread arrangements.
- [Unit frames and action bars](unitframes-and-actionbars.md): clean bars, cast bars, the action bars, and the Medallions action slab.
- [Settings and setup](settings-and-setup.md): the first-run setup and the `/kstyle` settings window.

Add one file per feature as verification grows. Keep the same four sections: `Sub-features`, `How to get to it (user POV)`, `Driving it with the render and regression harnesses`, and `Gotchas`. When a journey fails because a seed state lacks a precondition, record the reason in that feature's `Gotchas`. Never weaken the journey to make it pass.

Every command here assumes the Launch and Doctor steps in [the skill](../SKILL.md) already ran on this machine.
