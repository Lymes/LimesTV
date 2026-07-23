# App Store screenshots

Screenshots sized for App Store Connect submission, generated from the images in
`../images`.

## iPhone — 6.9" display (mandatory)

`iPhone-6.9/` — exact pixel sizes required by App Store Connect. This is the only
iPhone size you must upload: Apple auto-scales it down for all smaller iPhones
(6.5", 6.3", 6.1", …).

| File | Size | Orientation |
| --- | --- | --- |
| `01_channels_1290x2796.jpeg` | 1290 × 2796 | Portrait |
| `02_player_2796x1290.jpeg` | 2796 × 1290 | Landscape |
| `03_schedule_1290x2796.jpeg` | 1290 × 2796 | Portrait |

## iPad — not included

The app is Universal (`TARGETED_DEVICE_FAMILY = 1,2`), so App Store Connect also
requires **13" iPad** screenshots (2064 × 2752). These cannot be derived from the
iPhone captures (different aspect ratio) — capture them on an iPad / iPad
simulator, or set the app to iPhone-only if iPad isn't a target.

## Note

The source images are lower resolution than the target sizes, so these were
upscaled to meet the exact required dimensions; for the best App Store quality,
re-capture at native device resolution (iPhone 16 Pro Max for 6.9").
