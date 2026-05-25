#pragma once

#include <JuceHeader.h>
#include "juce_serialport/juce_serialport.h"

class MainComponent  : public juce::Component, private juce::Timer
{
public:
    //==============================================================================
    MainComponent(); 
    ~MainComponent() override;  

    //==============================================================================
    void paint (juce::Graphics&) override;
    void resized() override;

    void handleIncomingSerialLine(const juce::String& serialLine);
    void processSensorData(float hue, float sat, float light, int buttonState);

private:

    std::unique_ptr<SerialPort> arduinoPort;
    juce::String serialBuffer;
    std::unique_ptr<SerialPortInputStream> arduinoStream; 
    
    void timerCallback() override;
    
    // --- 1. GUI Components ---
    juce::ToggleButton noteToggle  { "Enable Note Out (Hue)" };
    juce::ToggleButton satToggle   { "Enable CC 70 (Saturation)" };
    juce::ToggleButton lightToggle { "Enable CC 71 (Lightness)" };

    // NUOVO: Menu a tendina per la Root Note
    juce::ComboBox rootSelector;
    juce::Label rootLabel;

    juce::ComboBox scaleSelector;
    juce::Label scaleLabel;

    // --- 2. GUI State Flags ---
    bool guiToggleNoteEnabled = true;
    bool guiToggleSatEnabled = true;
    bool guiToggleLightEnabled = true;

    // --- 3. MIDI State Tracking ---
    int lastPlayedNote = -1;
    bool wasPressedLastFrame = false;
    int lastSatCC = -1;
    int lastLightCC = -1;

    // --- 4. MIDI Output & Scale ---
    std::unique_ptr<juce::MidiOutput> virtualMidiOut;
    std::vector<int> scale; 

    // NUOVO: Funzione che ricostruisce la scala calcolando gli intervalli
    void rebuildScale();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (MainComponent)
};