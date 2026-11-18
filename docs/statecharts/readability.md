# Readability options

Appearance has four independent switches, enabled by default: Readable text on bars, Backing for text over the world, Chat tabs always readable, and Bar colour refinements. Off restores the original appearance for that group. Existing font and layout choices remain saved.

```mermaid
stateDiagram-v2
    Applied --> Applied: choose outside combat / apply values, rebuild default cast spacing, restyle
    Applied --> Pending: choose during combat / save choice
    Pending --> Pending: choose again / keep latest choices
    Pending --> Applied: combat ends / apply once and restyle
```

The applied values stay unchanged during combat. The deferred callback rebuilds Medallions defaults and uses Layout's normal resolver; saved positions are never rewritten. The world-text switch removes existing scrims when disabled, and skin bars restore their original height and label anchors.

`Widgets.Readability(key)` returns the applied value. `InkFor` chooses fill contrast, `InkText` applies it, and `TextScrim` respects the world-text switch. `ReadabilityChanged` precedes `ThemeChanged`; both run after the combat queue flushes.
