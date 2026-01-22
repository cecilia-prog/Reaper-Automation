# Reaper Batch Speech Scoring & Render Pipeline

## Overview

This repository contains an automated workflow that uses **Reaper as a deterministic scoring and render engine** within a larger, code-driven pipeline. 

The current implementation is designed to: 
- take pre-generated speech audio (e.g.  from TTS or voice cloning),
- apply music, ambience, and FX scoring defined in Reaper templates,
- render final outputs automatically and repeatably.

This mirrors the structure of the broader system (speech generation → post-processing → ffmpeg assembly) while allowing creative scoring decisions to live entirely inside authored Reaper templates.

---

## Status & Scope (Important)

This workflow reflects the **current testing and experimentation phase**. 

At this stage: 
- the focus is on validating creative behavior, pacing, and scoring approaches,
- templates and automation details are expected to evolve,
- the automation logic is intentionally kept simple and stable. 

As we move out of testing and toward higher-volume usage, additional orchestration layers (e.g. job definitions, batching, logging) can be introduced without changing the core Reaper automation.

---

## Core Design Principle

**Automation logic is generic.   
Creative variation lives in Reaper templates.**

Different speech contexts (e.g. indoor vs outdoor, crowd-heavy vs minimal, different speakers or eras) are handled by **separate Reaper templates**, not by separate automation scripts.

This keeps the system: 
- predictable
- debuggable
- easy to iterate creatively
- aligned with existing ffmpeg-based post-processing stages

---

## What the Script Does (Current Behavior)

For each audio file placed in `input_speech/`, the script:

1. Opens a specified Reaper template project
2. Finds a track named exactly `SPEECH`
3. Replaces the media source of the first item on that track (in place)
4. Resizes the item to match the new speech duration
5. Sets render bounds from item start → item end + tail
6. Renders using Reaper's most recent render settings
7. Writes the output file to `output/` with a deterministic name

All scoring logic (music beds, ambience, FX, ducking, dynamics) is authored in the template — not in the script.

---

## Folder Structure (Current)

```
SpeechRender/
├── templates/
│   ├── Template_MalcolmX_OutdoorRally. rpp
│   ├── Template_Thatcher_IndoorAddress.rpp
│   └── Template_GenericStudio. rpp
├── input_speech/
│   ├── speech_001.wav
│   ├── speech_002.wav
│   └── speech_003.wav
├── output/
│   ├── speech_001_PA. wav
│   ├── speech_002_PA.wav
│   └── speech_003_PA.wav
└── batch_replace_and_render.lua
```

---

## Template Requirements

Each Reaper template **must** include:

1. **A track named exactly:**
   ```
   SPEECH
   ```

2. **Exactly one placeholder media item** on the `SPEECH` track  
   - Its position defines speech start time
   - Automation, ducking, and scoring reference this item

3. **All creative logic authored in advance**, including:
   - music beds
   - crowd / room tone
   - reverb and spatial treatment
   - transitions and dynamics

The script assumes templates are fully authored and render-ready.

---

## Handling Different Speech Contexts

Different speech types do **not** require different scripts. 

Instead:
- use **different Reaper templates** for different contexts,
- keep the automation script unchanged. 

**Examples:**
- **Outdoor rally** → wider space, heavier crowd, stronger dynamics
- **Indoor address** → tighter room, minimal crowd, restrained scoring
- **Studio narration** → neutral ambience, minimal movement

This separation allows rapid creative iteration without touching pipeline code.

---

## One-Time Setup (Required)

Before running the script for the first time:

1. Open the desired template in Reaper
2. Go to `File → Render…`
3. Set:
   - Bounds:  **Time selection**
   - Output format (e.g. WAV)
   - Sample rate / bit depth
4. Perform **one manual render**

The script reuses Reaper's **most recent render settings** for all batch renders. 

---

## Input Audio Requirements

- Place speech files in:
  ```
  input_speech/
  ```
- **Supported formats:**
  - `.wav`
  - `.aif`
  - `.aiff`
  - `.mp3`
- Files are processed alphabetically
- Each input file produces one rendered output

---

## Output Behavior

- Outputs are written to:
  ```
  output/
  ```
- Filenames follow:
  ```
  <input_filename>_PA.wav
  ```
- Render length = speech duration + tail

---

## Tail Handling

An additional tail is added to each render:

```lua
local TAIL_SEC = 2.5
```

This allows time for:
- reverb decay
- applause
- musical resolution

Tail length can be adjusted as templates evolve.

---

## Automation & Pipeline Integration

This script is designed to run:
- manually from Reaper,
- via command line,
- or as part of a Python-driven pipeline (e.g. after TTS generation).

**Typical current flow:**

1. Speech audio is generated upstream
2. Files are placed in `input_speech/`
3. Reaper runs this script
4. Rendered outputs appear in `output/`
5. Downstream tools (e.g. ffmpeg) continue processing

Reaper functions as a deterministic scoring and render stage.

---

## Scaling & Batch Rendering (Planned)

As we move out of testing and into higher-volume usage (e.g. many speeches, multiple variants per speech), we anticipate introducing a lightweight job definition layer. 

Conceptually, this would:
- define which speech file maps to which template,
- support multiple variants per speech,
- enable batching, logging, and retries.

This may take the form of a `jobs.json` or similar schema managed upstream (e.g. in Python), while the Reaper script itself remains unchanged.

This separation allows the system to scale without increasing complexity inside Reaper.

---

## Error Handling & Warnings

The script will warn or exit if:
- the `SPEECH` track is missing,
- no placeholder item exists,
- no input audio files are found,
- the output directory is inaccessible.

If multiple items exist on the `SPEECH` track, only the first is used.

---

## Design Philosophy

- Scripts handle automation only
- Templates encode creative intent
- No runtime creative branching
- Identical inputs → predictable outputs

This keeps the system safe to automate, version, and evolve. 

---

## Intended Use Cases

- AI / TTS speech scoring
- Historical speech recontextualization
- Voice performance augmentation
- Automated composition and post-processing pipelines

---

## Next Steps

- Continued experimentation with scoring templates
- Validation across different speech lengths and contexts
- Introduction of job-based orchestration once testing stabilizes
- Alignment with final production pipeline once prototype access is available
