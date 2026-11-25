# Crest break-out: high-fidelity animated mockups (owner request)

The owner could not judge the break-out designs from stills and small GIFs: "I can't tell from these. Generate high fidelity animated mockups." Make one per class (and per form/stance where the crest changes a lot) for your family, using your Step 1 design (`crest-breakout-<family>/REPORT.md`).

Each mockup:
- **Crest-focused and crisp**: render at 5120x1440 (or 3840x2160) with the render harness over the owner's backdrop, crop to the crest plus the unit bars either side (so the fit with the bars is visible), output about 1280x720. No upscaled blur, no 1080 pixel doubling.
- **Real motion**: 30 fps, 10-15 s, a scripted fight beat: rest, pull, buffs applied, DoTs burning down, a proc, a cooldown going up, stacks building, an interrupt, a timer ending warning, back to rest. Every tracked effect of the class appears at least once in its key states (apply, active loop, ending warning, end). Smooth (no frame skips); use the real animation timings you designed.
- **Captions**: a small caption strip under the crest naming what just happened ("Rend applied", "Enrage", "Battle Shout ending"), in plain English.
- **Files**: H.264 MP4 (`ffmpeg -c:v libx264 -pix_fmt yuv420p -crf 23 -preset slow -movflags +faststart`, ffmpeg is at `~/.local/bin/ffmpeg`) under 450 KB each (shorten or lower crf to fit; never below readable quality), plus a poster PNG of the busiest frame. Name them `<class>[-<form>].mp4` in `C:/Users/leeba/.cache/kstyleui-evidence/crest-breakout-<family>/hifi/`.

At most 2 renders at once on this machine. No code changes to the PR. Report the file list (with sizes) when done, then wait for a go.
