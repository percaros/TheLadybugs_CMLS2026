<<<<<<< HEAD
@echo off
echo Booting up the system for the presentation...

:: 1. Start your JUCE Standalone Application
echo Launching JUCE Application...
start "" ""C:\Users\Saeed13709\OneDrive\Desktop\Giovanni.exe""

:: Wait 3 seconds for the JUCE app to initialize audio/MIDI devices
timeout /t 3 /nobreak > nul

:: 2. Start loopMIDI (Skip this if loopMIDI already runs on Windows startup)
echo Starting loopMIDI...
start "" "C:\Program Files (x86)\Tobias Erichsen\loopMIDI\loopMIDI.exe"

:: Wait 2 seconds to ensure the virtual ports are fully active
timeout /t 2 /nobreak > nul


:: 3. Launch the SuperCollider Script
echo Booting SuperCollider and VST3...
start "" "C:\Program Files\SuperCollider-3.14.1\sclang.exe" "C:\Users\Saeed13709\OneDrive\Desktop\Synth_wave_broken.scd"

echo All software launched successfully!
>>>>>>> 29a867ac0b70ae4cee57fa8554eddcffde338453
pause
