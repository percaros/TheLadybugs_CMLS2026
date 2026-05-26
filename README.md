
# TheLadybugs — CMLS 2026

> **Play colors. Make music.**
> An Arduino-based color sensor MIDI controller that maps the physical properties of color — hue, saturation, and lightness — to musical notes and synthesizer parameters in real time.

---

## Overview

TheLadybugs is an interactive music system built for the **Computer Music Languages and Systems (CMLS) 2026** course. A color sensor attached to an Arduino reads RGB color values from any surface. These get converted to HSL (Hue, Saturation, Lightness), then translated into MIDI messages and routed through a chain of custom software: a JUCE-based MIDI router, a SuperCollider wavetable synthesizer, and a JUCE VST3 effects plugin. The plugin parameters can also be controlled via a mobile phone thorugh a Open Stage Control interface.

```
[Arduino + Color Sensor]
        │  Serial (115200 baud)
        ▼
[JUCE App: Giovanni.exe]   ← Sensor MIDI Router
        │  MIDI (loopMIDI virtual port)
        ▼
[SuperCollider: Synth_wave_broken.scd]   ← Wavetable FM/PM Synthesizer
        │  Audio (internal bus)  +  OSC (Open Stage Control)
        ▼
[JUCE VST3: The_lady_bugs.vst3]   ← Granular + Delay + Reverb FX
        │
        ▼
     [Audio Output]
```

---

## System Components

### 1. Arduino Color Sensor
The Arduino reads a digital button's state and an RGB color sensor, converts the sensor data to HSL, and streams comma-separated values over serial at 115200 baud in the following format:

```
<hue>,<saturation>,<lightness>,<buttonState>
```

- **Hue** (0.0–1.0): determines the MIDI Note
- **Saturation** (0.0–1.0): mapped to MIDI CC 70 
- **Lightness** (0.0–1.0): mapped to MIDI CC 71
- **Button State** (0 or 1): triggers Note On / Note Off

---

### 2. JUCE Sensor MIDI Router (`Giovanni.exe` / `juce/`)

A standalone JUCE C++ application that reads the Arduino serial stream and converts it into MIDI messages sent to a virtual loopMIDI port.

**Features:**
- Reads from COM5 at 115200 baud (configurable in source)
- Quantizes hue to a musical **scale** over 2 octaves
- Supports **11 scales**: Major, Natural Minor, Harmonic Minor, Minor Pentatonic, Blues, Dorian, Phrygian, Lydian, Mixolydian, Whole Tone, Chromatic
- Selectable **root note** (C through B)
- Per-channel toggles for Note output, CC70 (Saturation), and CC71 (Lightness)
- Connects to loopMIDI virtual port for DAW/SuperCollider integration

**Color → MIDI Mapping:**

| Color Property | MIDI Message | Default Target |
|---|---|---|
| Hue | Note On/Off (Ch. 1) | Scale-quantized Note |
| Saturation | CC 70 (Ch. 1) | Wavetable position (Default) |
| Lightness | CC 71 (Ch. 1) | Filter cutoff (Default) |
| Button | Note trigger | Gate |

<img width="503" height="523" alt="WhatsApp Image 2026-05-26 at 22 57 15" src="https://github.com/user-attachments/assets/eea4e1f9-3382-4d5d-86df-925b4568dc49" />

---

### 3. SuperCollider Synthesizer (`Synth_wave_broken.scd`)

A SuperCollider script that boots a MIDI-responsive **wavetable synthesizer** with FM/PM modulation, a resonant filter, and VST3 FX routing.

**Synthesis Engine (`\wtOsc` SynthDef):**
- **16 wavetables** ranging from pure sine to complex spectral shapes (sawtooth, square, bell-like, noise-like, FM-distorted, and more)
- Smooth **wavetable interpolation** via `VOsc` — scrub through timbres in real time
- **FM (Frequency Modulation)** and **PM (Phase Modulation)** modes, switchable live
- Modulator with feedback, ratio, and depth controls
- **RLPF** resonant low-pass filter with cutoff and resonance
- ASR envelope with a soft release
- Lag smoothing on all parameters to prevent zipper noise

**MIDI CC Mapping (configurable in GUI):**

| CC | Default Mapping |
|---|---|
| CC 70 | Wavetable Position |
| CC 71 | Filter Cutoff |

Both CCs can be remapped in the GUI to: Position, Cutoff, Resonance, FM Ratio, FM Amount, FM Feedback, or Mod Mode.

**Synthesis Presets:**

| Preset | Mode | Description |
|---|---|---|
| Bell | Phase PM | Ratio 2.0, medium amount |
| Bass | Freq FM | Ratio 1.0, warm distortion |
| Metal | Phase PM | Ratio 2.75, inharmonic |
| Off | — | Disables modulation |

**VST3 FX Chain:**
SuperCollider routes audio through an internal bus to the JUCE VST3 plugin (`The_lady_bugs.vst3`) and controls it via OSC from Open Stage Control.

<img width="1118" height="942" alt="Screenshot 2026-05-26 225213" src="https://github.com/user-attachments/assets/b9b7cb14-7c6a-4ba1-a86c-ae1f25b35e85" />

---

### 4. JUCE VST3 Effects Plugin (`juce plugin/` / `The_lady_bugs.vst3`)

A JUCE audio plugin implementing a three-stage effects chain controlled by OSC messages from Open Stage Control.

**Effect Chain:**

| Stage | Parameters | OSC Address |
|---|---|---|
| **Granular** | Grain Size (10–200ms), Pitch (±12 st), Density (1–40 Hz), Mix | `/grain/grain_size`, `/grain/pitch`, `/grain/density`, `/grain/wet` |
| **Delay** | Time (10–2000ms), Feedback (0–0.95), Mix | `/delay/delay_time`, `/delay/feedback`, `/delay/wet` |
| **Reverb** | Size, Damping, Early Reflections, Mix, Type (Room/Hall/Plate) | `/reverb/size`, `/reverb/damping`, `/reverb/early_ref`, `/reverb/wet`, `/reverb/type` |

<img width="817" height="905" alt="Screenshot 2026-05-26 225203" src="https://github.com/user-attachments/assets/516f9d0a-c396-4df0-8b1d-59a5c09aa74b" />

---

### 5. Open Stage Control Session (`interfaccia_osc_grain.json`)

A touchscreen-compatible control interface built with [Open Stage Control](https://openstagecontrol.ammd.net/). Load this session file in the Open Stage Control app to get knobs and sliders for all VST3 FX parameters, sending OSC to SuperCollider on localhost.

---

## Requirements

### Hardware
- Arduino board with a compatible RGB color sensor 
- USB connection to PC (COM5 by default — update in `MainComponent.cpp` if needed)

### Software (Windows)
- [loopMIDI](https://www.tobias-erichsen.de/software/loopmidi.html) — virtual MIDI port (must have a port named `loopMIDI Port`)
- [SuperCollider](https://supercollider.github.io/) 3.14.1+
- [Open Stage Control](https://openstagecontrol.ammd.net/) 1.30.3+
- The compiled `Giovanni.exe` (JUCE MIDI Router)
- The compiled `The_lady_bugs.vst3` installed to `C:\Program Files\Common Files\VST3\`

### JUCE Dependencies (for building from source)
- JUCE framework
- `juce_serialport` module (for Arduino serial communication)

---

## Quick Start

### Automatic Launch (Windows)
A batch script is included to launch all components in the correct order:

```bat
@echo off.bat
```

This will:
1. Launch `Giovanni.exe` (MIDI Router)
2. Wait 3 seconds for audio/MIDI initialization
3. Launch loopMIDI
4. Wait 2 seconds for virtual ports
5. Launch SuperCollider with `Synth_wave_broken.scd`

> **Update the file paths** in the `.bat` file to match your installation before running.

### Manual Launch
1. Start **loopMIDI** and ensure a port named `loopMIDI Port` exists
2. Launch **Giovanni.exe** — it will connect to Arduino on COM5
3. Open **SuperCollider**, open `Synth_wave_broken.scd`, and evaluate the whole file (`Ctrl+Shift+Return`)
4. Open **Open Stage Control**, load `interfaccia_osc_grain.json`, and start the server
5. Point a color at the sensor and press the button to play!

---

## Building from Source

### JUCE MIDI Router (`juce/`)
1. Add the `juce_serialport` module to your JUCE project
2. Open/create a JUCE project targeting the `juce/` source files (`Main.cpp`, `MainComponent.cpp`, `MainComponent.h`)
3. Build as a Standalone Application

### JUCE VST3 Plugin (`juce plugin/`)
The `.txt` extension on the source files is for repository compatibility — rename them:
- `PluginProcessor.cpp.txt` → `PluginProcessor.cpp`
- `PluginProcessor.h.txt` → `PluginProcessor.h`
- `PluginEditor.cpp.txt` → `PluginEditor.cpp`
- `PluginEditor.h.txt` → `PluginEditor.h`

Build as a VST3 plugin and install to `C:\Program Files\Common Files\VST3\`.

---

## Repository Structure

```
TheLadybugs_CMLS2026/
├── juce/                        # JUCE MIDI Router (source)
│   ├── Main.cpp
│   ├── MainComponent.cpp
│   └── MainComponent.h
├── juce plugin/                 # JUCE VST3 FX Plugin (source)
│   ├── PluginProcessor.cpp.txt
│   ├── PluginProcessor.h.txt
│   ├── PluginEditor.cpp.txt
│   └── PluginEditor.h.txt
├── Synth_wave_broken.scd        # SuperCollider wavetable synthesizer
├── interfaccia_osc_grain.json   # Open Stage Control session
├── Giovanni.exe                 # Compiled JUCE MIDI Router
├── The_lady_bugs.vst3            # Compiled JUCE VST3 Plugin
├── @echo off.bat                # Windows auto-launch script
└── README.md
```

---

## Authors

**TheLadybugs** — CMLS 2026 Project Team

---

## License

This project was developed for academic purposes as part of the CMLS 2026 course. Please contact the authors for reuse or distribution.
