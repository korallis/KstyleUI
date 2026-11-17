# How a Forever release reaches CurseForge and Wago

Read on 2026-11-17. The packager is the one pinned in `.github/workflows/release.yml`: [BigWigsMods/packager v2.7.0](https://github.com/BigWigsMods/packager/tree/01e8631a69c69d7654c788d152630d5fed9e3812), file `release.sh` at that SHA.

KstyleUI is Forever-only. `KstyleUI.toc` is `## Interface: 16001` and `## AllowLoadGameType: camelot`. That is already enough for the packager to tag the zip as Forever 1.60.1. `.pkgmeta` and `release.yml` do not need a change. The only missing lines are the two project ids, and they go on the root TOC after the projects exist.

## What each site calls Forever

CurseForge lists it as its own flavor, **Forever**, `gameVersionTypeID` **88568**, version name **1.60.1**. The public addon search uses those values:

- Flavor: <https://www.curseforge.com/wow/search?class=addons&gameVersionTypeId=88568>
- Patch: <https://www.curseforge.com/wow/search?class=addons&version=1.60.1>

The packager sends `gameVersions` as the numeric id of the row whose `gameVersionTypeID` is 88568 and whose `name` is `1.60.1` ([release.sh lines 2901-2932](https://github.com/BigWigsMods/packager/blob/01e8631a69c69d7654c788d152630d5fed9e3812/release.sh#L2901-L2932)). If that exact name is missing, it warns and falls back to the next lower version of type 88568, then to the highest. No workflow edit is required for that fallback.

Wago lists it as the flavor `forever`. [The game-data API](https://addons.wago.io/api/data/game) (fetched 2026-11-17) has `patches.forever: ["1.60.1"]` and `live_patches.supported_forever_patches: "1.60.1"`. TOC suffixes it accepts are `-Camelot`, `_Camelot`, `-Forever`, `_Forever`. A single unflavored TOC is valid. KstyleUI does not need a `_Camelot.toc`.

The packager posts `supported_forever_patches` (plural, a one-element array) on `POST https://addons.wago.io/api/projects/<id>/version` ([release.sh lines 3138-3169](https://github.com/BigWigsMods/packager/blob/01e8631a69c69d7654c788d152630d5fed9e3812/release.sh#L3138-L3169)). [docs.wago.io](https://docs.wago.io/) still shows the older singular keys (`supported_retail_patch` and friends) and does not mention Forever. The pinned packager uses the plural key, which is what a live Forever file stores (Plater's `supported_forever_patches` is `["1.60.1"]` on its [project page](https://addons.wago.io/addons/plater-nameplates)).

## How 16001 becomes 1.60.1

`toc_to_type` maps an interface number matching `16???` to the game type `forever`. `camelot` is an alias of `forever` ([release.sh lines 80 and 207-220](https://github.com/BigWigsMods/packager/blob/01e8631a69c69d7654c788d152630d5fed9e3812/release.sh#L80)).

`set_build_version` turns the interface number into a patch by splitting off the last four digits ([release.sh line 1377](https://github.com/BigWigsMods/packager/blob/01e8631a69c69d7654c788d152630d5fed9e3812/release.sh#L1377)):

```text
16001 -> 1 . 60 . 01 -> 1.60.1
```

`## AllowLoadGameType: camelot` is a client loading rule. The packager does not read it. Leave it. It is what keeps the addon off Retail and Classic.

A `_Mainline.toc` may contain 16001. A `_Classic.toc` may not ([release.sh lines 1237-1256](https://github.com/BigWigsMods/packager/blob/01e8631a69c69d7654c788d152630d5fed9e3812/release.sh#L1237-L1256)). KstyleUI has neither. One root TOC is the right shape.

The zip name gains `-forever` on its own. The default template is `{package-name}-{project-version}{classic}`. On a tag such as `v0.2.3`, which does not already contain `-forever`, `{classic}` becomes `-forever` ([release.sh lines 156-166](https://github.com/BigWigsMods/packager/blob/01e8631a69c69d7654c788d152630d5fed9e3812/release.sh#L156-L166)). The file is `KstyleUI-v0.2.3-forever.zip`, which is the name the README already tells players to expect. Do not add a filename template to `.pkgmeta`.

## What the other Forever addons do

| Addon | TOC | Upload |
| --- | --- | --- |
| [BigWigs](https://github.com/BigWigsMods/BigWigs/blob/master/BigWigs.toc) | One `## Interface:` line that includes `16001` among the other flavors. `## X-Curse-Project-ID: 2382` and `## X-Wago-ID: 5NRegwG3`. No Forever key in [`.pkgmeta`](https://github.com/BigWigsMods/BigWigs/blob/master/.pkgmeta). | [build.yml](https://github.com/BigWigsMods/BigWigs/blob/master/.github/workflows/build.yml) calls the packager once, with `CF_API_KEY`, `WAGO_API_TOKEN` and `GITHUB_OAUTH`. No `-g`. |
| [Grid2](https://github.com/michaelnpsp/Grid2/blob/main/Grid2.toc) | `## Interface: 120105, 16001` plus `## Interface-Retail: 120105` and `## Interface-Forever: 16001`. `## X-Curse-Project-ID: 15226` and `## X-Wago-ID: vEGPyeN1`. [`.pkgmeta-retail`](https://github.com/michaelnpsp/Grid2/blob/main/.pkgmeta-retail) has no game-version key. | [build.yml](https://github.com/michaelnpsp/Grid2/blob/main/.github/workflows/build.yml) runs the packager twice, `-g retail` and `-g forever`, because one TOC covers both. Both passes get `CF_API_KEY` and `WAGO_API_TOKEN`. |
| [Decursive](https://github.com/2072/Decursive/blob/master/Decursive.toc) | `## Interface-Forever: 16001` beside Retail, Classic, Titan and Mists lines. `## X-Curse-Project-ID: 2154`. No `X-Wago-ID`. [`.pkgmeta`](https://github.com/2072/Decursive/blob/master/.pkgmeta) has no game-version key. | [build-package-and-upload.yml](https://github.com/2072/Decursive/blob/master/.github/workflows/build-package-and-upload.yml) runs a separate job with `-g forever` (packager v2.6.1) so that upload is Forever-only. It sets `CF_API_KEY` and does not set `WAGO_API_TOKEN`. |

KstyleUI matches BigWigs's single-package shape, not Grid2's or Decursive's split, because 16001 is the only interface number in the TOC. `-g forever` would select the same version the packager already selects. It is not required.

The packager reads `X-Curse-Project-ID` and `X-Wago-ID` from the package TOC, which `.pkgmeta` names with `package-as: KstyleUI`, so the file is the root `KstyleUI.toc` ([release.sh lines 1343-1358](https://github.com/BigWigsMods/packager/blob/01e8631a69c69d7654c788d152630d5fed9e3812/release.sh#L1343-L1358)). The module TOCs do not need the lines. The CurseForge id must be numeric. A slug is ignored ([release.sh lines 1502-1504](https://github.com/BigWigsMods/packager/blob/01e8631a69c69d7654c788d152630d5fed9e3812/release.sh#L1502-L1504)). The Wago id is the 8-character id printed under the project name on <https://addons.wago.io/developers> ([docs.wago.io](https://docs.wago.io/#adding-the-wago-project-id)).

## Tokens the workflow already passes

`release.yml` already exports `CF_API_KEY` and `WAGO_API_TOKEN` from the GitHub `release` environment into the packager step. Both secrets are unset until the owner adds them.

The packager reads `CF_API_TOKEN`, then `CF_API_KEY` if that is empty ([release.sh lines 506-512](https://github.com/BigWigsMods/packager/blob/01e8631a69c69d7654c788d152630d5fed9e3812/release.sh#L506-L512)). The README of the packager calls `CF_API_KEY` deprecated and prefers `CF_API_TOKEN`. The deprecated name still works at this SHA, and it is the name BigWigs, Grid2 and Decursive still set. Leave `release.yml` on `CF_API_KEY`.

`WAGO_API_TOKEN` is the name [docs.wago.io](https://docs.wago.io/#github-actions) tells you to export. It is already exported.

CurseForge's token is created at <https://authors.curseforge.com/#/settings/api-tokens>. The console's generate call sends a name and no scopes (`POST /_api/user-settings/api-tokens/generate` with `{name}`). One token is the whole API key. The packager sends it as the `x-api-token` header ([the upload API](https://support.curseforge.com/en/support/solutions/articles/9000197321-curseforge-upload-api)).

Wago's key is created at <https://addons.wago.io/account/apikeys>. [docs.wago.io](https://docs.wago.io/#authentication) describes one bearer token and no scopes. The packager sends `Authorization: Bearer <token>`.

The icon pack stays a GitHub release asset. CurseForge and Wago install into `AddOns`. The pack belongs in `_forever_/Interface/Icons`. `release.yml` already says so and already uploads it with `gh release upload`. Do not add it to either store page's file.

## Proposed diff

Do not apply this until the numeric CurseForge id and the 8-character Wago id exist. Nothing else changes.

```diff
--- a/KstyleUI.toc
+++ b/KstyleUI.toc
@@ -6,6 +6,8 @@
 ## Author: korallis
 ## Version: @project-version@
 ## Category: Interface
+## X-Curse-Project-ID: <numeric CurseForge project id>
+## X-Wago-ID: <8-character Wago project id>
 ## X-Website: https://github.com/korallis/KstyleUI
 ## X-License: All Rights Reserved
 ## OptionalDeps: LibSharedMedia-3.0
```

No `.pkgmeta` diff. No `release.yml` diff. No `-g forever`. No `## Interface-Forever` line. No id lines on the module TOCs.
