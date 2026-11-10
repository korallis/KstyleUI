# Folio type specification

This is the default Folio measurement for the owner-approved type change (LEE-113). It replaces the old picture’s **text ink targets only**. Layout rectangles, bars, tracks and fixed boxes keep their existing contracts. The content-sized loot card and section rules may follow text width; they may not exceed their existing limits.

Measured at 3456×2234 and revalidated over staging `24f875a081fea7040941847bb7360c675e1befa8`, including #265's GroupFrames fitting and #267's native menus. The implementation is not yet merged. All six fresh baseline/Folio HUD PNGs are byte- and RGB-identical to their original `f21dae0d` counterparts, and all 401 text records match exactly. The companion `type-spec-data.json` retains the original measurement provenance and adds that verified-base bridge. It preserves every visible text record in DPS, Tank and Healer, with source hashes, edges, baselines and cap/x metrics. Values below describe the intended default, not arbitrary saved overrides or native-client validation.

## Faces and role tokens

| Role | Nominal root-unit size | Folio face |
| --- | ---: | --- |
| display / heading | 22 / 16 | IM Fell Double Pica SC |
| title / caps | 12 / 10 | EB Garamond 600 derivative, Folio Caps |
| names / unit | 10 / 18 | Cinzel 600 derivatives |
| body / prose / caption | 12 / 12 / 11 | PT Serif Regular |
| number / time | 12 / 12 | PT Serif Bold |
| timer / world | 11 / 13 | PT Serif Regular |

Folio Caps bakes +0.045 em tracking and +0.08 em word spacing; names bake zero tracking and +0.16 em word spacing; unit bakes −0.064 em tracking and +0.25 em word spacing. Generated capitals are mapped in the file. No synthetic thin spaces are inserted into Folio or unknown custom faces. PT Serif has native equal-width lining digits. `world` retains its existing outline and scaling exception. Gold caps remain `capsGold` (#d3b574). Sources, licences and exact build transformations are in `Media/PROVENANCE.md`.

## Reading the measurements

One root unit is 2234/1282.5 physical pixels. Effective em includes the element’s own scale and physical-pixel snapping, so it need not equal the nominal token. Cap/x are Chrome’s actual bounding-box heights for H and x at that effective em, in physical pixels; generated all-caps faces map x to X. These are font metrics, not thresholded screenshot ink or a claim about the game renderer. Baselines are the integer pixel positions actually used by the renderer. Allow one physical pixel for raster rounding, not a moved anchor or a lost line.

L/C/R means the left advance edge, centre, or right advance edge. Insets are root units from the named Layout element or story-card edge; a centred value is an offset from its centre. For engine/world nameplates and aura tiles, the reference is their own text box, not an unrelated HUD card. A negative inset can describe text intentionally outside its parent’s body, such as an aura timer or an XP caption; it is not permission to overlap another element.

## Baseline and edge partnerships

- The clock and coordinates share baseline 414px. The clock stays on the minimap’s right edge; the zone and coordinates stay on its left edge.
- Story caps and their counts share baselines: guide/step 490px; quests/total 613px. Objective/count pairs share 823, 897 and 971px. Four quest titles, four blue badges and all objective lines remain visible.
- Player name, class, health value and maximum share 1917px; target name, creature type and percent share 1733px. Cast name/time pairs share 1534px (player caption bar) and 1847px (target). Their bars do not change.
- Chat tabs share 1922px; six message baselines are 1960, 1992, 2024, 2056, 2088 and 2120px: the 32px pitch is unchanged. The fresh settings are size 12/spacing 6.5. Explicit values remain; migration preserves the old implicit partner when only size or spacing was customised.
- Damage title/summary share 1970px; each spell/value/percent/dot group shares 2012, 2048, 2084, 2120 or 2156px. The data readout’s labels, values and separators share 1912px. Loot plus/name pairs share 1713, 1762 and 1811px.

## Native DPS text inventory

Every visible text object is included, including all acceptance-probed strings. Repeated labels remain distinct by ID and owner. The JSON carries multi-line ink boxes and all three preset inventories without rounding.

| ID / owner | Text | Role | Effective em (root) | H / x (px) | Baseline(s) px | Edge px / inset root |
| --- | --- | --- | ---: | ---: | --- | --- |
| DPS-1 · story rail | Talk to Aarnor Galestrike | body | 13.204 | 16.10 / 11.50 | 531 | L 2994 / 29.774 |
| DPS-2 · story rail | Train your class spells | body | 13.204 | 16.10 / 11.50 | 564 | L 2994 / 29.774 |
| DPS-3 · story rail | 1-9 SKYBORNE | caps | 12.056 | 13.82 / 13.92 | 490 | L 2994 / 29.774 |
| DPS-4 · story rail | Step 134 | number | 12.056 | 14.70 / 10.50 | 490 | R 3400 / 15.149 |
| DPS-5 · world nameplate | SHADOWGALE POACHER | names | 12.056 | 14.70 / 14.70 | 919 | C 1210 / -0.048 |
| DPS-6 · world nameplate | SHADOWGALE POACHER | names | 12.056 | 14.70 / 14.70 | 993 | C 2308 / -0.268 |
| DPS-7 · world nameplate | POACHER LOOKOUT | names | 12.056 | 14.70 / 14.70 | 1200 | C 2639 / -0.247 |
| DPS-8 · chat.main | GENERAL | names | 12.056 | 14.70 / 14.70 | 1922 | C 110 / -150.697 |
| DPS-9 · chat.main | COMBAT LOG | names | 12.056 | 14.70 / 14.70 | 1922 | C 268 / -59.992 |
| DPS-10 · chat.main | [Worn Leather Vest] has been added to your appearance collection. | body | 12.056 | 14.70 / 10.50 | 2120 | L 58 / 16.074 |
| DPS-11 · chat.main | You receive loot: [Worn Leather Vest] | body | 12.056 | 14.70 / 10.50 | 2088 | L 58 / 16.074 |
| DPS-12 · chat.main | You receive loot: [Bug Eye] | body | 12.056 | 14.70 / 10.50 | 2056 | L 58 / 16.074 |
| DPS-13 · chat.main | You have gained 1 talent point. | body | 12.056 | 14.70 / 10.50 | 2024 | L 58 / 16.074 |
| DPS-14 · chat.main | You have gained 17 hit points and 30 mana. | body | 12.056 | 14.70 / 10.50 | 1992 | L 58 / 16.074 |
| DPS-15 · chat.main | Congratulations, you have reached [Level 11]! | body | 12.056 | 14.70 / 10.50 | 1960 | L 58 / 16.074 |
| DPS-16 · minimap.main | WINDFIELD ORCHARD | names | 12.056 | 14.70 / 14.70 | 386 | L 3104 / 1.722 |
| DPS-17 · minimap.main | 9:20 PM | time | 12.630 | 15.40 / 11.00 | 414 | R 3425 / 1.722 |
| DPS-18 · minimap.main | 46.2, 61.8 | body | 11.482 | 14.00 / 10.00 | 414 | L 3104 / 1.722 |
| DPS-19 · minimap.main | N | heading | 8.611 | 10.91 / 6.66 | 32 | C 3264 / -0.287 |
| DPS-20 · auras.buffs | 45s | timer | 10.908 | 13.30 / 9.50 | 101 | C 2570 / -139.502 |
| DPS-21 · auras.buffs | 2m | timer | 10.908 | 13.30 / 9.50 | 101 | C 2624 / -108.502 |
| DPS-22 · auras.buffs | 4m | timer | 10.908 | 13.30 / 9.50 | 101 | C 2678 / -77.501 |
| DPS-23 · auras.buffs | 6m | timer | 10.908 | 13.30 / 9.50 | 101 | C 2732 / -46.501 |
| DPS-24 · auras.buffs | 9m | timer | 10.908 | 13.30 / 9.50 | 101 | C 2786 / -15.500 |
| DPS-25 · auras.buffs | 14m | timer | 10.908 | 13.30 / 9.50 | 101 | C 2840 / 15.500 |
| DPS-26 · auras.buffs | 28m | timer | 10.908 | 13.30 / 9.50 | 101 | C 2894 / 46.501 |
| DPS-27 · auras.buffs | 58m | timer | 10.908 | 13.30 / 9.50 | 101 | C 2948 / 77.501 |
| DPS-28 · auras.buffs | 10m | timer | 10.908 | 13.30 / 9.50 | 101 | C 3002 / 108.502 |
| DPS-29 · auras.buffs | 23m | timer | 10.908 | 13.30 / 9.50 | 101 | C 3056 / 139.502 |
| DPS-30 · auras.debuffs | 7s | timer | 10.908 | 13.30 / 9.50 | 187 | C 3002 / 108.502 |
| DPS-31 · auras.debuffs | 18s | timer | 10.908 | 13.30 / 9.50 | 187 | C 3056 / 139.502 |
| DPS-32 · databars.strip | · | body | 12.056 | 14.70 / 10.50 | 1912 | C 3286 / 58.556 |
| DPS-33 · databars.strip | · | body | 12.056 | 14.70 / 10.50 | 1912 | C 3351 / 95.872 |
| DPS-34 · databars.strip | fps | body | 12.056 | 14.70 / 10.50 | 1912 | L 3253 / 178.540 |
| DPS-35 · databars.strip | 162 | body | 12.056 | 14.70 / 10.50 | 1912 | L 3216 / 157.299 |
| DPS-36 · databars.strip | ms | body | 12.056 | 14.70 / 10.50 | 1912 | L 3318 / 215.855 |
| DPS-37 · databars.strip | 15 | body | 12.056 | 14.70 / 10.50 | 1912 | L 3293 / 201.503 |
| DPS-38 · databars.strip | 26s 16c | body | 12.056 | 14.70 / 10.50 | 1912 | L 3357 / 238.244 |
| DPS-39 · databars.xp | Level 11 · 0% · rested 5% | prose | 12.056 | 14.70 / 10.50 | 2196 | C 1727 / -0.287 |
| DPS-40 · story rail | QUESTS | caps | 12.056 | 13.82 / 13.92 | 613 | L 2994 / 29.774 |
| DPS-41 · story rail | 7 | number | 12.056 | 14.70 / 10.50 | 613 | R 3400 / 15.149 |
| DPS-42 · story rail | 1 | number | 9.759 | 11.90 / 8.50 | 658 | C 2984 / -114.967 |
| DPS-43 · story rail | [11] Unnerving Silence | body | 13.204 | 16.10 / 11.50 | 659 | L 3012 / 40.107 |
| DPS-44 · story rail | Find and speak with Elegael Thornpaw in the northeastern part of Shadowgale Forest. | body | 13.204 | 16.10 / 11.50 | 689, 719, 749 | L 3012 / 40.107 |
| DPS-45 · story rail | 2 | number | 9.759 | 11.90 / 8.50 | 792 | C 2984 / -114.967 |
| DPS-46 · story rail | [9] Crab Season | body | 13.204 | 16.10 / 11.50 | 793 | L 3012 / 40.107 |
| DPS-47 · story rail | Windsong Crawler Meat | body | 13.204 | 16.10 / 11.50 | 823 | L 3012 / 40.107 |
| DPS-48 · story rail | 0/6 | number | 13.204 | 16.10 / 11.50 | 823 | R 3398 / 16.297 |
| DPS-49 · story rail | 3 | number | 9.759 | 11.90 / 8.50 | 866 | C 2984 / -114.967 |
| DPS-50 · story rail | [11] Aid For The Refugees | body | 13.204 | 16.10 / 11.50 | 867 | L 3012 / 40.107 |
| DPS-51 · story rail | Abandoned Belongings | body | 13.204 | 16.10 / 11.50 | 897 | L 3012 / 40.107 |
| DPS-52 · story rail | 0/8 | number | 13.204 | 16.10 / 11.50 | 897 | R 3398 / 16.297 |
| DPS-53 · story rail | 4 | number | 9.759 | 11.90 / 8.50 | 940 | C 2984 / -114.967 |
| DPS-54 · story rail | [12] A Grand Adventure | body | 13.204 | 16.10 / 11.50 | 941 | L 3012 / 40.107 |
| DPS-55 · story rail | Listen to Ayessa | body | 13.204 | 16.10 / 11.50 | 971 | L 3012 / 40.107 |
| DPS-56 · story rail | 0/1 | number | 13.204 | 16.10 / 11.50 | 971 | R 3398 / 16.297 |
| DPS-57 · meters.damage | DAMAGE | caps | 12.056 | 13.82 / 13.92 | 1970 | C 3058 / -76.640 |
| DPS-58 · meters.damage | 14.9 dps | number | 12.056 | 14.70 / 10.50 | 1970 | R 3398 / 16.074 |
| DPS-59 · meters.damage | Lightning Bolt | body | 12.056 | 14.70 / 10.50 | 2012 | L 2997 / 22.963 |
| DPS-60 · meters.damage | 412 | number | 12.056 | 14.70 / 10.50 | 2012 | R 3330 / 55.112 |
| DPS-61 · meters.damage | 46% | number | 12.056 | 14.70 / 10.50 | 2012 | R 3386 / 22.963 |
| DPS-62 · meters.damage | · | number | 12.056 | 14.70 / 10.50 | 2012 | R 3340 / 49.371 |
| DPS-63 · meters.damage | Flame Shock | body | 12.056 | 14.70 / 10.50 | 2048 | L 2997 / 22.963 |
| DPS-64 · meters.damage | 188 | number | 12.056 | 14.70 / 10.50 | 2048 | R 3331 / 54.538 |
| DPS-65 · meters.damage | 21% | number | 12.056 | 14.70 / 10.50 | 2048 | R 3386 / 22.963 |
| DPS-66 · meters.damage | · | number | 12.056 | 14.70 / 10.50 | 2048 | R 3341 / 48.797 |
| DPS-67 · meters.damage | Earth Shock | body | 12.056 | 14.70 / 10.50 | 2084 | L 2997 / 22.963 |
| DPS-68 · meters.damage | 134 | number | 12.056 | 14.70 / 10.50 | 2084 | R 3331 / 54.538 |
| DPS-69 · meters.damage | 15% | number | 12.056 | 14.70 / 10.50 | 2084 | R 3386 / 22.963 |
| DPS-70 · meters.damage | · | number | 12.056 | 14.70 / 10.50 | 2084 | R 3341 / 48.797 |
| DPS-71 · meters.damage | Melee | body | 12.056 | 14.70 / 10.50 | 2120 | L 2997 / 22.963 |
| DPS-72 · meters.damage | 107 | number | 12.056 | 14.70 / 10.50 | 2120 | R 3331 / 54.538 |
| DPS-73 · meters.damage | 12% | number | 12.056 | 14.70 / 10.50 | 2120 | R 3386 / 22.963 |
| DPS-74 · meters.damage | · | number | 12.056 | 14.70 / 10.50 | 2120 | R 3341 / 48.797 |
| DPS-75 · meters.damage | Searing Totem | body | 12.056 | 14.70 / 10.50 | 2156 | L 2997 / 22.963 |
| DPS-76 · meters.damage | 54 | number | 12.056 | 14.70 / 10.50 | 2156 | R 3342 / 48.223 |
| DPS-77 · meters.damage | 6% | number | 12.056 | 14.70 / 10.50 | 2156 | R 3386 / 22.963 |
| DPS-78 · meters.damage | · | number | 12.056 | 14.70 / 10.50 | 2156 | R 3353 / 41.908 |
| DPS-79 · target aura tile | 9s | timer | 12.056 | 14.70 / 10.50 | 1774 | C 2367 / 0.000 |
| DPS-80 · target aura tile | 3s | timer | 12.056 | 14.70 / 10.50 | 1774 | C 2422 / 0.000 |
| DPS-81 · unitframes.castbar.player | LIGHTNING BOLT | names | 12.056 | 14.70 / 14.70 | 1534 | L 1426 / 0.000 |
| DPS-82 · unitframes.castbar.player | 1.2 / 2.5 | time | 12.056 | 14.70 / 10.50 | 1534 | R 2030 / 0.000 |
| DPS-83 · unitframes.target | SHADOW BOLT | names | 12.056 | 14.70 / 14.70 | 1847 | L 1300 / -0.000 |
| DPS-84 · unitframes.target | 0.8 | time | 12.056 | 14.70 / 10.50 | 1847 | R 2155 / 0.000 |
| DPS-85 · unitframes.player | 11 | number | 13.204 | 16.10 / 11.50 | 1977 | C 1252 / -272.976 |
| DPS-86 · unitframes.player | KORALLIS | unit | 21.815 | 26.60 / 26.60 | 1917 | L 1300 / -0.000 |
| DPS-87 · unitframes.player | Shaman | caption | 13.778 | 16.80 / 12.00 | 1917 | L 1495 / 111.946 |
| DPS-88 · unitframes.player | 203 | number | 14.926 | 18.20 / 13.00 | 1917 | R 2095 / 34.445 |
| DPS-89 · unitframes.player | / 237 | caption | 14.926 | 18.20 / 13.00 | 1917 | R 2155 / 0.000 |
| DPS-90 · unitframes.target | 12 | number | 13.778 | 16.80 / 12.00 | 1794 | C 2202 / 272.402 |
| DPS-91 · unitframes.target | SHADOWGALE POACHER | unit | 21.815 | 26.60 / 26.60 | 1733 | R 2153 / 1.148 |
| DPS-92 · unitframes.target | Humanoid | caption | 14.352 | 17.50 / 12.50 | 1733 | R 1680 / 272.689 |
| DPS-93 · unitframes.target | 50% | number | 14.926 | 18.20 / 13.00 | 1733 | L 1300 / -0.000 |
| DPS-94 · actionbars.bar1 | 1 | number | 10.908 | 13.30 / 9.50 | 2098 | L 1305 / 2.870 |
| DPS-95 · actionbars.bar1 | 2 | number | 10.908 | 13.30 / 9.50 | 2098 | L 1377 / 44.204 |
| DPS-96 · actionbars.bar1 | 3 | number | 10.908 | 13.30 / 9.50 | 2098 | L 1449 / 85.538 |
| DPS-97 · actionbars.bar1 | 4 | number | 10.908 | 13.30 / 9.50 | 2098 | L 1521 / 126.872 |
| DPS-98 · actionbars.bar1 | 5 | number | 10.908 | 13.30 / 9.50 | 2098 | L 1593 / 168.206 |
| DPS-99 · actionbars.bar1 | 6 | number | 10.908 | 13.30 / 9.50 | 2098 | L 1665 / 209.540 |
| DPS-100 · actionbars.bar1 | 7 | number | 10.908 | 13.30 / 9.50 | 2098 | L 1737 / 250.874 |
| DPS-101 · actionbars.bar1 | 8 | number | 10.908 | 13.30 / 9.50 | 2098 | L 1809 / 292.208 |
| DPS-102 · actionbars.bar1 | 9 | number | 10.908 | 13.30 / 9.50 | 2098 | L 1881 / 333.542 |
| DPS-103 · actionbars.bar1 | 0 | number | 10.908 | 13.30 / 9.50 | 2098 | L 1952 / 374.302 |
| DPS-104 · actionbars.bar1 | - | number | 10.908 | 13.30 / 9.50 | 2098 | L 2024 / 415.636 |
| DPS-105 · actionbars.bar1 | = | number | 10.908 | 13.30 / 9.50 | 2098 | L 2096 / 456.970 |
| DPS-106 · actionbars.bar2 | Q | number | 10.908 | 13.30 / 9.50 | 2026 | L 1305 / 2.870 |
| DPS-107 · actionbars.bar2 | E | number | 10.908 | 13.30 / 9.50 | 2026 | L 1377 / 44.204 |
| DPS-108 · actionbars.bar2 | R | number | 10.908 | 13.30 / 9.50 | 2026 | L 1449 / 85.538 |
| DPS-109 · actionbars.bar2 | F | number | 10.908 | 13.30 / 9.50 | 2026 | L 1521 / 126.872 |
| DPS-110 · actionbars.bar2 | Z | number | 10.908 | 13.30 / 9.50 | 2026 | L 1593 / 168.206 |
| DPS-111 · actionbars.bar2 | X | number | 10.908 | 13.30 / 9.50 | 2026 | L 1665 / 209.540 |
| DPS-112 · actionbars.bar2 | C | number | 10.908 | 13.30 / 9.50 | 2026 | L 1737 / 250.874 |
| DPS-113 · actionbars.bar2 | V | number | 10.908 | 13.30 / 9.50 | 2026 | L 1809 / 292.208 |
| DPS-114 · player aura tile | 8s | timer | 10.908 | 13.30 / 9.50 | 1959 | C 1035 / -0.027 |
| DPS-115 · player aura tile | 14s | timer | 10.908 | 13.30 / 9.50 | 1959 | C 1091 / 0.060 |
| DPS-116 · cooldowns.essential | 4 | number | 16.648 | 20.30 / 14.50 | 1628 | C 1548 / -103.335 |
| DPS-117 · cooldowns.essential | 12 | number | 16.648 | 20.30 / 14.50 | 1628 | C 1764 / 20.667 |
| DPS-118 · qol.lootfeed | + | number | 13.778 | 16.80 / 12.00 | 1713 | C 65 / -138.928 |
| DPS-119 · qol.lootfeed | Bug Eye | body | 13.778 | 16.80 / 12.00 | 1713 | L 135 / 60.279 |
| DPS-120 · qol.lootfeed | + | number | 13.778 | 16.80 / 12.00 | 1762 | C 65 / -138.928 |
| DPS-121 · qol.lootfeed | Worn Leather Vest | body | 13.778 | 16.80 / 12.00 | 1762 | L 135 / 60.279 |
| DPS-122 · qol.lootfeed | + | number | 13.778 | 16.80 / 12.00 | 1811 | C 65 / -138.928 |
| DPS-123 · qol.lootfeed | 14c | body | 13.778 | 16.80 / 12.00 | 1811 | L 135 / 60.279 |

## Retired probes and retained limits

The untouched acceptance-4 audit exits 1 because the wider clock and target-class text reach the left edges of their old ink ROIs. The original failure is retained. A separately labelled diagnostic records those six preset/ROI clips and continues the non-text measurements without changing any ROI or threshold. All bar ramp profiles, empty-track samples, XP edge spans, badge records, quest counts and Layout element records remain exactly equal to staging. The only non-text drawable changes are text-following section rules and the content-sized loot chrome.

The new clock and target-class edges/baselines are the rows above, not clipped measurements from those retired ROIs. Pass 5 must choose its fixed probe windows around these measured default targets, preserving the same alignment, inset and partner rules rather than forcing the new face into the old ink envelope.

GroupFrames keeps its theme-name sentinel: roomy lanes use the names role, while compact lanes retain the explicit Alegreya Sans Regular file. Health intentionally retains Alegreya Sans ExtraBold. Its 12-letter raid-name guarantee remains intact. zhCN/zhTW/koKR still use the client’s font for every bundled face. Russian substitutes the client font for IM Fell and Cinzel, while Folio Caps and PT Serif retain their Cyrillic glyphs. External user faces remain the user’s choice; no glyph coverage or tabular figures are promised for them.

The initial nine-screen/five-locale HUD matrix has 135 cases per source, with exactly matching finding sets: 89 passes and 46 baseline failures each. Those failures include the Healer world-nameplate fixture crossing cards and zhCN fallback-metric truncations. These are historical results: the renderer's unquoted `Source Sans 3` fallback was invalid CSS, so Canvas could retain its default 10px size for unshipped fonts. The corrected, calibrated comparisons below supersede those CJK measurements. The forged material fixes the old 720p chat-border overhang.

## Fixed lanes and content-sized surfaces

No Layout rectangle, bar, fixed box or name floor changes. The loot card hugs its longest line inside its existing 318-root-unit cap and slot. Its normal fixture grows from 307 to 334 physical pixels at 3456×2234 and from 101 to 110 at 1280×720, inside slots of 554 and 179 pixels. Equal inner padding stays 28 and 10 pixels respectively. Deliberately long item names ellipsize inside that cap. Locale runs use the actual English item fixtures, not translated item-name coverage.

Other content-sized surfaces are tooltips, fitted chat tabs, toggle-label hit areas, the unforced Reload now button and text-following section rules. Their natural text widths may change; this is not permission to expand a fixed allocation. The Options tooltip preview instead preserves its box, anchors and row pitch while fitting paired left/right ink down to the existing 8-root-unit minimum.

Player/target column names retain the `unit` role (CinzelUnit Medium in baseline; CinzelUnit SemiBold in Folio). Across 108 frozen nine-screen, three-preset, four-Latin-locale HUD pairs, all 432 real name instances remain whole at their configured size, with unchanged allocations and anchors. The minimum remaining room is 42.874 physical pixels. Healer world-nameplate fixture collisions are separate from these player/target lanes.

The frFR Options sample `Hurleur du givre` is an accepted bounded preview exception: eight more instances ellipsize across seven screens with Folio, inside unchanged reserved name lanes. Complete retained characters and a complete `...` run fit the outward-rounded native pixel boxes, with no partial foreground-glyph clipping. Existing configured shadows can paint up to two pixels beyond the rectangle in either source. The affected screens are 1280×720, 1366×768, 1920×1080, 2560×1440, 3440×1440, 5120×1440 and 3456×2234. This does not establish every arbitrary NPC/player name or native-client rendering.

## Final gallery fit evidence

The preserved initial matrix contains 4,410 renders. A separate 1,206-render delta on `bafa97fa` covers 324 affected Latin cases and 441 paired Folio/calibrated-baseline zhCN cases, with zero infrastructure errors. All affected authored Latin labels fit whole: zero authored findings and zero horizontal clips exceeding one physical pixel. The 18 remaining Latin strict failures are French/Spanish game-data preview names at the unchanged floor, not kit-authored labels. All 45 repacked aura-count cases pass.

Setup notes use the smaller Folio caps size with the body face; the preview accounts for actual line height and uses the concise Loot label. The shorter QoL sentence and German/Spanish bag categories avoid authored truncation. Merchant stock names use the Folio caps size with the body face. Lumen keeps its body-sized notes and merchant names, but the preview line-height correction and concise translated copy apply to both sets.

The corrected CJK proxy pairs add no Folio findings: Folio has 392 strict passes/49 failures against 390/51 for the calibrated baseline. Both use the same corrected renderer, and 43,903 unshipped-font measurements record the effective `ctx.font` alongside the requested size, with zero mismatches. This baseline is explicitly calibrated, not the raw original baseline. Residual findings include HUD, DataBars, GroupFrames, WorldMap, Chat and Meters. Client-owned ARKai_T.ttf is absent and Lua still estimates its advances, so these proxy results do not certify whole native CJK labels. Native Chinese/Korean font loading and fit remain an in-game check.

## Reproduction

The #265 rebase adds 180 GroupFrames-related calibrated pairs with no new Folio findings (129 passes/51 retained failures per source). All 72 uncovered Latin fallback cases in Cooldowns and RestedXP also pass without new authored or painted horizontal clips; 1,368 all-shipped-font cases need no renderer recalibration. The #267 rebase adds 270 native-menu cases with ForgedBrackets explicitly enabled, not the scenes' Native/off default. All 108 Folio Latin cases pass; the 27 CJK proxy failures match the calibrated baseline, and no pair adds a Folio finding. All native menu rows remain visible. Unchanged source boundaries and fresh HUD captures bind the earlier fit evidence to the final base.

The retained source-snapshot and browser-metric harness is at `~/.capy/work/KSTY-22/type-matrix-final/`; the separate fit delta is in `delta-1/`, and the rebase coverage is in `rebase-14b37c04/` and `rebase-24f875a0/`. Original acceptance outputs are at `~/.capy/work/KSTY-22/acceptance-f21/`; the final six native captures, repeated acceptance-4 bundle results and exact source/pixel/record bridge are at `~/.capy/work/KSTY-22/acceptance-24f875a0/`. Exact preview-name runs, pixel containment, screen/lane deltas and source hashes are in `~/.capy/work/KSTY-22/data-name-proof/REPORT.md`. The browser diagnostics call the existing renderer and only record measurements. Guard verdicts run `guard.lua` directly: the earlier KSTY-19 screen wrapper did not set `arg[0]` and could return false success. This specification never uses those old exit-zero claims as proof.
