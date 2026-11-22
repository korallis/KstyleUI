# Window finish options

The Skins page offers Steel window buttons and Consistent window spacing. Button material changes apply immediately. Native spacing uses the existing reload prompt so Blizzard rebuilds its anchors with the saved choice; both choices default on.

```mermaid
stateDiagram-v2
    [*] --> Applied: Load saved spacing choice
    Applied --> ReloadNeeded: Change Consistent window spacing
    ReloadNeeded --> ReloadNeeded: Defer reload or change the choice
    ReloadNeeded --> Applied: Reload UI and apply saved choice
    Applied --> Applied: Change Steel window buttons
```

The quest continuation, story alignment, meter fitting, data-strip docking, minimap plaque clearance, bag-heading and bag-figure switches refresh their matching module immediately. Switching them off restores their previous arrangement.
