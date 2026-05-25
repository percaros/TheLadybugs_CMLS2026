#include "MainComponent.h"

//==============================================================================
MainComponent::MainComponent()
{
    // --- 1. Make the GUI visible ---
    addAndMakeVisible(noteToggle);
    addAndMakeVisible(satToggle);
    addAndMakeVisible(lightToggle);
    
    addAndMakeVisible(rootLabel);
    addAndMakeVisible(rootSelector);
    addAndMakeVisible(scaleLabel);
    addAndMakeVisible(scaleSelector);

    // --- 2. Set default states ---
    noteToggle.setToggleState(true, juce::dontSendNotification);
    satToggle.setToggleState(true, juce::dontSendNotification);
    lightToggle.setToggleState(true, juce::dontSendNotification);

    // ROOT SETUP
    rootLabel.setText("Root:", juce::dontSendNotification);
    rootLabel.setJustificationType(juce::Justification::centredLeft);
    
    const juce::StringArray roots = {"C", "C# / Db", "D", "D# / Eb", "E", "F", "F# / Gb", "G", "G# / Ab", "A", "A# / Bb", "B"};
    for (int i = 0; i < roots.size(); ++i)
        rootSelector.addItem(roots[i], i + 1);
        
    rootSelector.setSelectedId(1, juce::dontSendNotification); // Default: C

    // SCALE SETUP
    scaleLabel.setText("Scale:", juce::dontSendNotification);
    scaleLabel.setJustificationType(juce::Justification::centredLeft);

    scaleSelector.addItem("Major (Ionian)", 1);
    scaleSelector.addItem("Natural Minor (Aeolian)", 2);
    scaleSelector.addItem("Harmonic Minor", 3);
    scaleSelector.addItem("Minor Pentatonic", 4);
    scaleSelector.addItem("Blues", 5);
    scaleSelector.addItem("Dorian", 6);
    scaleSelector.addItem("Phrygian", 7);
    scaleSelector.addItem("Lydian", 8);
    scaleSelector.addItem("Mixolydian", 9);
    scaleSelector.addItem("Whole Tone", 10);
    scaleSelector.addItem("Chromatic", 11);
    
    scaleSelector.setSelectedId(4, juce::dontSendNotification); // Default: Minor Pentatonic

    // --- 3. Link the buttons/menus to our code ---
    noteToggle.onClick  = [this] { guiToggleNoteEnabled  = noteToggle.getToggleState(); };
    satToggle.onClick   = [this] { guiToggleSatEnabled   = satToggle.getToggleState(); };
    lightToggle.onClick = [this] { guiToggleLightEnabled = lightToggle.getToggleState(); };
    
    // Quando uno dei due menu cambia, ricalcoliamo la scala
    rootSelector.onChange = [this] { rebuildScale(); };
    scaleSelector.onChange = [this] { rebuildScale(); };

    // Inizializza l'array della scala all'avvio
    rebuildScale();

    // --- 4. Open the Virtual MIDI Port ---
    auto devices = juce::MidiOutput::getAvailableDevices();
    for (auto d : devices)
    {
        if (d.name == "loopMIDI Port") 
        {
            virtualMidiOut = juce::MidiOutput::openDevice(d.identifier); 
            break;
        }
    }

    // Finestra leggermente più alta per far spazio alla nuova riga
    setSize (400, 390);

    arduinoPort = std::make_unique<SerialPort>(juce::String("COM5"), nullptr); 

    SerialPortConfig config;
    config.bps = 115200;
    arduinoPort->setConfig(config);

    if (arduinoPort->exists())
    {
        arduinoStream = std::make_unique<SerialPortInputStream>(arduinoPort.get());
        startTimer(10);
    }
}

MainComponent::~MainComponent()
{
}

//==============================================================================
void MainComponent::paint (juce::Graphics& g)
{
    g.fillAll (getLookAndFeel().findColour (juce::ResizableWindow::backgroundColourId));

    g.setColour (juce::Colours::white);
    g.setFont (24.0f);
    g.drawText ("Sensor MIDI Router", getLocalBounds().removeFromTop(60), 
                juce::Justification::centred, true);
}

void MainComponent::resized()
{
    auto area = getLocalBounds().reduced(40); 
    area.removeFromTop(60); 

    int rowHeight = 30;
    int spacing = 15;

    // Draw the Root Selector row
    auto rootRow = area.removeFromTop(rowHeight);
    rootLabel.setBounds(rootRow.removeFromLeft(50));
    rootSelector.setBounds(rootRow);
    
    area.removeFromTop(spacing);

    // Draw the Scale Selector row
    auto scaleRow = area.removeFromTop(rowHeight);
    scaleLabel.setBounds(scaleRow.removeFromLeft(50)); 
    scaleSelector.setBounds(scaleRow);                 
    
    area.removeFromTop(spacing);

    // Draw the toggles
    noteToggle.setBounds(area.removeFromTop(rowHeight));
    area.removeFromTop(spacing);
    
    satToggle.setBounds(area.removeFromTop(rowHeight));
    area.removeFromTop(spacing);
    
    lightToggle.setBounds(area.removeFromTop(rowHeight));
}

//==============================================================================
void MainComponent::processSensorData(float hue, float sat, float light, int buttonState)
{
    if (virtualMidiOut == nullptr || scale.empty()) return; 

    // --- QUANTIZE THE PITCH ---
    int maxIndex = (int)scale.size() - 1;
    int noteIndex = juce::roundToInt(hue * maxIndex);
    int currentNote = scale[noteIndex];

    // --- NOTE ON / OFF LOGIC ---
    bool isPressed = (buttonState == 1);

    if (isPressed && !wasPressedLastFrame) 
    {
        if (guiToggleNoteEnabled) 
        {
            virtualMidiOut->sendMessageNow(juce::MidiMessage::noteOn(1, currentNote, 1.0f));
            lastPlayedNote = currentNote;
        }
    }
    else if (!isPressed && wasPressedLastFrame) 
    {
        if (lastPlayedNote != -1) 
        {
            virtualMidiOut->sendMessageNow(juce::MidiMessage::noteOff(1, lastPlayedNote));
            lastPlayedNote = -1; 
        }
    }
    wasPressedLastFrame = isPressed;

    // --- CONTROL CHANGE LOGIC (KNOBS) ---
    int satCC = (int)(sat * 127.0f);
    int lightCC = (int)(light * 127.0f);

    if (guiToggleSatEnabled && satCC != lastSatCC) 
    {
        virtualMidiOut->sendMessageNow(juce::MidiMessage::controllerEvent(1, 70, satCC)); 
        lastSatCC = satCC;
    }

    if (guiToggleLightEnabled && lightCC != lastLightCC) 
    {
        virtualMidiOut->sendMessageNow(juce::MidiMessage::controllerEvent(1, 71, lightCC)); 
        lastLightCC = lightCC;
    }
}

void MainComponent::timerCallback()
{
    if (arduinoStream != nullptr && !arduinoStream->isExhausted()) 
    {
        char buffer[256];
        int bytesRead = arduinoStream->read(buffer, 256); 
        
        if (bytesRead > 0) 
        {
            juce::String incomingData(juce::CharPointer_UTF8(buffer), bytesRead);
            serialBuffer += incomingData;
            
            int newlineIndex;
            while ((newlineIndex = serialBuffer.indexOfChar('\n')) != -1) 
            {
                juce::String line = serialBuffer.substring(0, newlineIndex).trim();
                handleIncomingSerialLine(line); 
                
                serialBuffer = serialBuffer.substring(newlineIndex + 1);
            }
        }
    }
}

void MainComponent::handleIncomingSerialLine(const juce::String& serialLine)
{
    juce::StringArray tokens;
    tokens.addTokens(serialLine, ",", "\"");

    if (tokens.size() >= 4)
    {
        float hue = tokens[0].getFloatValue();       
        float saturation = tokens[1].getFloatValue(); 
        float lightness = tokens[2].getFloatValue();  
        int buttonState = tokens[3].getIntValue();    

        processSensorData(hue, saturation, lightness, buttonState);
    }
}

// --- NUOVA LOGICA: Costruzione dinamica della scala ---
void MainComponent::rebuildScale()
{
    scale.clear();

    // 1. Troviamo la nota MIDI di base. L'ID 1 è "C", mappiamolo a C4 (MIDI 60)
    int rootId = rootSelector.getSelectedId(); // Da 1 a 12
    int baseNote = 60 + (rootId - 1);

    // 2. Definiamo gli intervalli su 2 ottave (24 semitoni) per la scala scelta
    int scaleId = scaleSelector.getSelectedId();
    std::vector<int> intervals;

    switch (scaleId)
    {
        case 1: // Maggiore (Ionian)
            intervals = {0, 2, 4, 5, 7, 9, 11, 12, 14, 16, 17, 19, 21, 23, 24}; break;
        case 2: // Minore Naturale (Aeolian)
            intervals = {0, 2, 3, 5, 7, 8, 10, 12, 14, 15, 17, 19, 20, 22, 24}; break;
        case 3: // Minore Armonica
            intervals = {0, 2, 3, 5, 7, 8, 11, 12, 14, 15, 17, 19, 20, 23, 24}; break;
        case 4: // Pentatonica Minore
            intervals = {0, 3, 5, 7, 10, 12, 15, 17, 19, 22, 24}; break;
        case 5: // Blues
            intervals = {0, 3, 5, 6, 7, 10, 12, 15, 17, 18, 19, 22, 24}; break;
        case 6: // Dorica
            intervals = {0, 2, 3, 5, 7, 9, 10, 12, 14, 15, 17, 19, 21, 22, 24}; break;
        case 7: // Frigia
            intervals = {0, 1, 3, 5, 7, 8, 10, 12, 13, 15, 17, 19, 20, 22, 24}; break;
        case 8: // Lidia
            intervals = {0, 2, 4, 6, 7, 9, 11, 12, 14, 16, 18, 19, 21, 23, 24}; break;
        case 9: // Misolidia
            intervals = {0, 2, 4, 5, 7, 9, 10, 12, 14, 16, 17, 19, 21, 22, 24}; break;
        case 10: // Toni Interi
            intervals = {0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24}; break;
        case 11: // Cromatica
            intervals = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 
                         13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24}; break;
        default:
            intervals = {0}; break;
    }

    // 3. Applichiamo la formula matematica (Nota Base + Intervallo) all'array finale
    for (int interval : intervals)
    {
        scale.push_back(baseNote + interval);
    }
}