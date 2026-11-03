# MRH1 mood board

The four reference images (Pinterest) were sent as chat images and could not be exported from the cloud session.
**Drop the four images into this folder** (`ref-1.jpg` … `ref-4.jpg`) so Claude Code can look at them.

## What the references set (agreed with the owner)

- Light warm paper background, ink text, minimal UI, minimal branding
- One orange accent ("ember"), soft blurred gradient orbs (peach / orange, a touch of violet) behind the header
- Black pill buttons and black filled selected states
- A row of day circles at the top (week strip), the selected day filled ink
- Round icon buttons (42–44 pt circles, frosted glass) and round tab icons
- Big rounded cards (26–30 pt radius) on the paper
- Font used in prototypes: Geist (SF Pro is fine natively)

## Tokens (light)

| Token | Value | Use |
|---|---|---|
| paper | #EDEBE7 | background |
| card | #FAF9F7 | cards |
| ink | #151413 | text, pills, selected |
| graphite | #77726C | secondary text |
| hair | #DFDBD5 | dividers, empty tracks |
| ember | #F0582A | brand accent only: today, strain, focus |
| peach | #F3A79E | orbs |
| iris | #8B88F0 | sleep, night |

Status colours are reserved for results ("green means good, yellow is the limit, red is danger"):

| Status | Phone (light) | Chip background | Chip text |
|---|---|---|---|
| good | #2F9D68 | #DDF0E4 | #237A50 |
| limit (yellow) | #E6B820 | #FBF0C8 | #8A6A08 |
| danger | #D23A3A | #F8DCD8 | #A92C2C |

Dark and evening variants are in `../v1-direction/index.html` (`.phone.night`).

## Owner feedback to respect

- v0.4 palette "cheap", WebGL gradient "garbage" → fixed in v1 direction (OKLab mixing, dithering, calm drift, orbs only at the top).
- First v1 draft removed too many features → **never remove features**; every v0.4 graph stays.
- Keep the mood board look on every screen.
