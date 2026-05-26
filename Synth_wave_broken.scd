(
s.waitForBoot({
    var wtSize = 1024;
    var numWaves = 16;
    var sigs; //empty box for waves formulas

    // ============================================================
    // 1. CLEANUP (Moved inside the boot block)
    // ============================================================
    CmdPeriod.run;

    if(~wtWin.notNil, {
        try { ~wtWin.close }; //close the interface window
        ~wtWin = nil;
    });

    if(~wt.notNil, {
        ~wt.do({ |b|
            try { b.free };  //free all the buffers (avoid out of memory)
        });
        ~wt = nil;
    });

    ~wtSigs = nil;
    ~numWaves = nil;

    // Free MIDI responders if they exist
    if(~noteOn.notNil) { ~noteOn.free };
    if(~noteOff.notNil) { ~noteOff.free };
    if(~cc.notNil) { ~cc.free };

    // ============================================================
    // MAIN
    // ============================================================

    // --- VST ROUTING ---
    ~fxBus = Bus.audio(s, 2);

    SynthDef(\vstWrapper, { |inBus = 0, outBus = 0|  //plugin wrapper
        var sig = In.ar(inBus, 2);
        var fx = VSTPlugin.ar(sig, 2);
        Out.ar(outBus, fx);
    }).add;

    // Initialize MIDI Client and connect to available ports
    MIDIClient.init;
    MIDIIn.connectAll;

    // ============================================================
    // OPEN STAGE CONTROL → VST FX CONTROL (OSC)
    // ============================================================

    // 1.Granular
    OSCdef(\grainGrain_Size, { |msg|
        var val = msg[1].asFloat.clip(0.0, 1.0);
        "OSC Grain -> ".post; val.postln;
        if(~vstCtrl.notNil) { ~vstCtrl.set(0, val) };
    }, "/grain/grain_size");
    OSCdef(\grainPitch, { |msg|
        var val = msg[1].asFloat.clip(0.0, 1.0);
        "OSC Grain -> ".post; val.postln;
        if(~vstCtrl.notNil) { ~vstCtrl.set(1, val) };
    }, "/grain/pitch");
    OSCdef(\grainDensity, { |msg|
        var val = msg[1].asFloat.clip(0.0, 1.0);
        "OSC Grain -> ".post; val.postln;
        if(~vstCtrl.notNil) { ~vstCtrl.set(2, val) };
    }, "/grain/density");
    OSCdef(\grainWet, { |msg|
        var val = msg[1].asFloat.clip(0.0, 1.0);
        "OSC Grain -> ".post; val.postln;
        if(~vstCtrl.notNil) { ~vstCtrl.set(3, val) };
    }, "/grain/wet");

    // 2.Delay
    OSCdef(\delayTime, { |msg|
        var val = msg[1].asFloat.clip(0.0, 1.0);
        "OSC Delay -> ".post; val.postln;
        if(~vstCtrl.notNil) { ~vstCtrl.set(4, val) };
    }, "/delay/delay_time");
    OSCdef(\delayFeedback, { |msg|
        var val = msg[1].asFloat.clip(0.0, 1.0);
        "OSC Delay -> ".post; val.postln;
        if(~vstCtrl.notNil) { ~vstCtrl.set(5, val) };
    }, "/delay/feedback");
    OSCdef(\delayWet, { |msg|
        var val = msg[1].asFloat.clip(0.0, 1.0);
        "OSC Delay -> ".post; val.postln;
        if(~vstCtrl.notNil) { ~vstCtrl.set(6, val) };
    }, "/delay/wet");

    // 3.Reverb
    OSCdef(\reverbSize, { |msg|
        var val = msg[1].asFloat.clip(0.0, 1.0);
        "OSC Reverb -> ".post; val.postln;
        if(~vstCtrl.notNil) { ~vstCtrl.set(7, val) };
    }, "/reverb/size");
    OSCdef(\reverbDamping, { |msg|
        var val = msg[1].asFloat.clip(0.0, 1.0);
        "OSC Reverb -> ".post; val.postln;
        if(~vstCtrl.notNil) { ~vstCtrl.set(8, val) };
    }, "/reverb/damping");
    OSCdef(\reverbEarly_Ref, { |msg|
        var val = msg[1].asFloat.clip(0.0, 1.0);
        "OSC Reverb -> ".post; val.postln;
        if(~vstCtrl.notNil) { ~vstCtrl.set(10, val) };
    }, "/reverb/early_ref");
    OSCdef(\reverbWet, { |msg|
        var val = msg[1].asFloat.clip(0.0, 1.0);
        "OSC Reverb -> ".post; val.postln;
        if(~vstCtrl.notNil) { ~vstCtrl.set(9, val) };
    }, "/reverb/wet");

    // 4. Controllo Reverb Type (Menu a tendina)
    OSCdef(\reverbType, { |msg|
        var testReceived = msg[1].asSymbol;
        var numericalValue = 0.0;

        switch(testReceived,
            'Room',  { numericalValue = 0.0; },
            'Hall',  { numericalValue = 0.5; },
            'Plate', { numericalValue = 1.0; }
        );

        "OSC Reverb Type -> ".post; testReceived.post; " | Map -> ".post; numericalValue.postln;

        if(~vstCtrl.notNil) { ~vstCtrl.set(11, numericalValue) };

    }, "/reverb/type");

    // ============================================================
    // WAVETABLE BUFFERS
    // ============================================================
    ~wt = Buffer.allocConsecutive(numWaves + 1, s, wtSize * 2, 1);
    s.sync;

    // ============================================================
    // WAVETABLES
    // ============================================================
    sigs = Array.newClear(numWaves);
    sigs[0] = Signal.sineFill(wtSize, [1]);
    sigs[1] = Signal.sineFill(wtSize, Array.fill(32, { |i| if((i % 2) == 0, { 1 / ((i + 1) ** 2) }, { 0 }) }));
    sigs[2] = Signal.sineFill(wtSize, Array.fill(8, { |i| if((i % 2) == 0, { 1 / (i + 1) }, { 0 }) }));
    sigs[3] = Signal.sineFill(wtSize, Array.fill(32, { |i| if((i % 2) == 0, { 1 / (i + 1) }, { 0 }) }));
    sigs[4] = Signal.sineFill(wtSize, Array.fill(8, { |i| 1 / (i + 1) }));
    sigs[5] = Signal.sineFill(wtSize, Array.fill(48, { |i| 1 / (i + 1) }));
    sigs[6] = Signal.sineFill(wtSize, Array.fill(24, { |i| (1 / (i + 1)) * cos(i * 0.4) }));
    sigs[7] = Signal.sineFill(wtSize, Array.fill(24, { |i| exp(-1 * ((i - 4).squared / 8)) }));
    sigs[8] = Signal.sineFill(wtSize, Array.fill(24, { |i| exp(-1 * ((i - 8).squared / 6)) }));
    sigs[9] = Signal.sineFill(wtSize, Array.fill(24, { |i| exp(-1 * ((i - 2).squared / 3)) + (0.7 * exp(-1 * ((i - 12).squared / 4))) }));
    sigs[10] = Signal.sineFill(wtSize, Array.fill(32, { |i| sin(i * 0.7).abs * (1 / (i + 1).sqrt) }));
    sigs[11] = Signal.sineFill(wtSize, [1, 0, 0.6, 0, 0.4, 0, 0, 0.3, 0, 0, 0.2, 0, 0, 0, 0.15]);
    sigs[12] = Signal.fill(wtSize, { |i| var x = i / wtSize * 2pi; sin(sin(x) * 3 + cos(x * 2)) });
    sigs[13] = Signal.fill(wtSize, { |i| var x = (i / wtSize * 2) - 1; tanh(x * 3) * 0.9 });
    sigs[14] = Signal.sineFill(wtSize, Array.fill(40, { |i| 1 / (i + 1) }), Array.fill(40, { |i| (i * 1.7).sin * pi }));
    sigs[15] = Signal.sineFill(wtSize, Array.fill(48, { 1.0 }));

    sigs.do({ |sig, i|
        sig = sig.normalize;
        ~wt[i].sendCollection(sig.asWavetable);
    });
    ~wt[numWaves].sendCollection(sigs[numWaves - 1].normalize.asWavetable);
    ~wtSigs = sigs.collect(_.normalize);
    ~numWaves = numWaves;

    s.sync;

    // ============================================================
    // SYNTHDEF
    // ============================================================
    SynthDef(\wtOsc, { |out = 0, freq = 110, amp = 0.3, pos = 0, gate = 1, cutoff = 8000,
        res = 0.3, fmRatio = 1, fmAmount = 0, fmFeedback = 0, modMode = 1|

        var posLag, freqLag, cutoffLag, resLag, ratioLag, amountLag, feedbackLag, modeLag;
        var env, fbIn, modulator, fbPhase, sigFM, sigPM, sig, carrierFreq, fmDepth, pmIndex, bufPos;

        freqLag = Lag.kr(freq.clip(20, 12000), 0.05);
        posLag = Lag.kr(pos.clip(0, ~numWaves - 1), 0.08);
        cutoffLag = Lag.kr(cutoff.clip(40, 18000), 0.05);
        resLag = Lag.kr(res.clip(0.05, 1.0), 0.05);
        ratioLag = Lag.kr(fmRatio.clip(0.125, 16), 0.05);
        amountLag = Lag.kr(fmAmount.clip(0, 1), 0.05);
        feedbackLag = Lag.kr(fmFeedback.clip(0, 0.2), 0.05);
        modeLag = Lag.kr(modMode.clip(0, 1), 0.03);

        bufPos = ~wt[0].bufnum + posLag;

        fbIn = LocalIn.ar(1);
        fbPhase = fbIn.tanh * feedbackLag * 2pi;
        modulator = SinOsc.ar(freqLag * ratioLag, fbPhase);
        LocalOut.ar(modulator.tanh);

        //FM
        fmDepth = amountLag * 0.5;
        carrierFreq = freqLag + (modulator * fmDepth * freqLag);
        carrierFreq = carrierFreq.clip(20, 16000);
        sigFM = VOsc.ar(bufPos, carrierFreq, phase: 0, mul: amp);

        //PM
        pmIndex = amountLag * 5.0;
        sigPM = VOsc.ar(bufPos, freqLag, phase: modulator * pmIndex, mul: amp);

        sig = SelectX.ar(modeLag, [sigFM, sigPM]);
        sig = RLPF.ar(sig, cutoffLag, resLag);
        sig = LeakDC.ar(sig);
        sig = tanh(sig * 1.2) * 0.85;

        env = EnvGen.kr(Env.asr(0.01, 1, 0.35), gate, doneAction: 2);
        Out.ar(out, (sig * env).dup);
    }).add;

	// --- VST START ---
    ~vstSynth = Synth(\vstWrapper, [\inBus, ~fxBus, \outBus, 0]);
    ~vstCtrl = VSTPluginController(~vstSynth);

    // 1. Force a quick scan of the VST3 folder to catch any newly compiled plugins
    VSTPlugin.search(s, "C:/Users/Saeed13709/OneDrive/Desktop/TheLadybugs_CMLS2026-main", action: {

        // 2. Open the specific plugin
        ~vstCtrl.open(""C:/Users/Saeed13709/OneDrive/Desktop/TheLadybugs_CMLS2026-main/The_lady_bugs.vst3"", editor: true, action: { |plugin|
            if(plugin.notNil) {
                "Juce interface loaded!".postln;

                // 3. CRUCIAL FIX: Defer the GUI launch to the AppClock
                {
                    ~vstCtrl.editor;
                }.defer;

            } {
                "Error! Could not find or load the VST3. Check the file name.".error;
            }
        });
    });
    s.sync;
    // ============================================================
    // GUI
    // ============================================================
    {
        var win, stackDisplay, waveDisplay;
        var posSlider, freqSlider, cutoffSlider, resSlider;
        var fmRatioSlider, fmAmountSlider, fmFbSlider;
        var playBtn, modeMenu;

        var cc70Menu, cc71Menu;
        var mapItems, ccMap, applySensorMapping;
        var lastCc70 = -1.0;
        var lastCc71 = -1.0;

        var startSynth, stopSynth;
        var currentPos = 0.0, currentFreq = 110, currentCutoff = 8000, currentRes = 0.3;
        var currentFmRatio = 1.0, currentFmAmount = 0.0, currentFmFb = 0.0, currentModMode = 1;
        var synth = nil;
        var bgColor = Color.new255(20, 22, 28);
        var fgColor = Color.new255(255, 140, 0);
        var fmColor = Color.new255(120, 200, 255);
        var sensorColor = Color.new255(180, 220, 180);
        var ratioToSlider;

        ratioToSlider = { |ratio|
            ratio.explin(0.25, 8, 0, 1).clip(0, 1) };

        // ============================================================
        // MIDI CC MAPPING DATA
        // ============================================================
        mapItems = ["Off", "Position", "Cutoff", "Resonance", "FM Ratio", "FM Amount", "FM Feedback", "Mod Mode"];
        ccMap = [1, 2]; // Default: CC70 -> Position, CC71 -> Cutoff

        // ============================================================
        // WINDOW & DISPLAY
        // ============================================================
        win = Window("Wavetable Synth - MIDI Mappable FM / PM", Rect(100, 100, 900, 720)).background_(bgColor).front;
        ~wtWin = win;

        stackDisplay = UserView(win, Rect(20, 60, 860, 240)).background_(Color.new255(10, 12, 16)).drawFunc_({ |v|
            var w = v.bounds.width, h = v.bounds.height;
            var visibleHalf = 5, perspectiveX = 22, perspectiveY = 14, waveWidth = 360, waveHeight = 50;
            var centerX = w * 0.5, centerY = h * 0.55;
            var firstWave = (currentPos.floor - visibleHalf).max(0).asInteger;
            var lastWave = (currentPos.ceil + visibleHalf).min(numWaves - 1).asInteger;

            (lastWave .. firstWave).do({ |i|
                var sig = ~wtSigs[i], relPos = i - currentPos, distance = relPos.abs;
                var alpha = (1 - (distance / (visibleHalf + 1))).max(0.12), alpha255 = (alpha * 255).asInteger.clip(0, 255);

                var isCurrent = distance < 1;
                var x = centerX + (relPos * perspectiveX) - (waveWidth * 0.5), y = centerY - (relPos * perspectiveY);
                var color = if(isCurrent, { Color.new255(255, 140, 0, alpha255) }, { Color.new255(180, 100, 30, (alpha255 * 0.7).asInteger) });
                Pen.strokeColor = color;
                Pen.width = if(isCurrent, { 2.5 }, { 1.0 });
                Pen.moveTo(x @ (y - (sig[0] * waveHeight * 0.5)));

                (1 .. waveWidth - 1).do({ |px|
                    var idx = (px / waveWidth * (sig.size - 1)).asInteger.clip(0, sig.size - 1);
                    Pen.lineTo((x + px) @ (y - (sig[idx] * waveHeight * 0.5)));
                });
                Pen.stroke;
                Pen.stringAtPoint(i.asString, (x - 18) @ (y - 6), Font("Monaco", 10), color);
            });
        });

        waveDisplay = UserView(win, Rect(20, 320, 860, 180)).background_(Color.new255(10, 12, 16)).drawFunc_({ |v|
            var w = v.bounds.width, h = v.bounds.height;
            var idxLow = currentPos.floor.asInteger.clip(0, numWaves - 1), idxHigh = (idxLow + 1).clip(0, numWaves - 1);
            var frac = currentPos - idxLow, sigLow = ~wtSigs[idxLow], sigHigh = ~wtSigs[idxHigh];
            var modeName = if(currentModMode == 0, { "FREQ FM" }, { "PHASE PM" });

            Pen.strokeColor = Color.new255(60, 60, 70); Pen.width = 1; Pen.line(0 @ (h / 2), w @ (h / 2)); Pen.stroke;
            Pen.strokeColor = fgColor; Pen.width = 2.5; Pen.moveTo(0 @ (h / 2));

            (1 .. w - 1).do({ |px|
                var idx = (px / w * (sigLow.size - 1)).asInteger.clip(0, sigLow.size - 1);
                var sample = (sigLow[idx] * (1 - frac)) + (sigHigh[idx] * frac);
                Pen.lineTo(px @ ((h / 2) - (sample * h * 0.35)));
            });
            Pen.stroke;

            if(currentFmAmount > 0.001, {
                Pen.strokeColor = Color.new255(120, 200, 255, 150); Pen.width = 1.5; Pen.moveTo(0 @ (h / 2));
                (1 .. w - 1).do({ |px|
                    var modSample = sin((px / w) * 2pi * currentFmRatio) * currentFmAmount;
                    Pen.lineTo(px @ ((h / 2) - (modSample * h * 0.25)));
                });
                Pen.stroke;
            });

            Pen.stringAtPoint("POS: %  (% -> %, mix %)".format(currentPos.round(0.01), idxLow, idxHigh, frac.round(0.01)), 10 @ 10, Font("Monaco", 11), fgColor);
            Pen.stringAtPoint("MODE: %".format(modeName), 10 @ 28, Font("Monaco", 11), fmColor);
            Pen.stringAtPoint("RATIO: % | AMOUNT: % | FB: %".format(currentFmRatio.round(0.01), currentFmAmount.round(0.001), currentFmFb.round(0.001)), 10 @ 46, Font("Monaco", 11), fmColor);
        });

        // ============================================================
        // OSCILLATOR CONTROLS
        // ============================================================
        StaticText(win, Rect(20, 510, 200, 20)).string_("-- OSCILLATOR --").stringColor_(fgColor).font_(Font("Monaco", 11, true));
        StaticText(win, Rect(20, 535, 90, 20)).string_("POSITION").stringColor_(fgColor).font_(Font("Monaco", 10));
        posSlider = Slider(win, Rect(115, 535, 305, 20)).background_(Color.new255(40, 40, 50)).knobColor_(fgColor).value_(0)
            .action_({ |sl| currentPos = sl.value * (numWaves - 1); stackDisplay.refresh; waveDisplay.refresh; if(synth.notNil, { synth.set(\pos, currentPos); }); });

        StaticText(win, Rect(20, 565, 90, 20)).string_("FREQ").stringColor_(fgColor).font_(Font("Monaco", 10));
        freqSlider = Slider(win, Rect(115, 565, 305, 20)).background_(Color.new255(40, 40, 50)).knobColor_(fgColor).value_(0.3)
            .action_({ |sl|
                currentFreq = sl.value.linexp(0, 1, 20, 8000);
                if(synth.notNil, { synth.set(\freq, currentFreq); });
            });

        StaticText(win, Rect(20, 595, 90, 20)).string_("CUTOFF").stringColor_(fgColor).font_(Font("Monaco", 10));
        cutoffSlider = Slider(win, Rect(115, 595, 305, 20)).background_(Color.new255(40, 40, 50)).knobColor_(fgColor).value_(0.8)
            .action_({ |sl| currentCutoff = sl.value.linexp(0, 1, 100, 18000); if(synth.notNil, { synth.set(\cutoff, currentCutoff); }); });

        StaticText(win, Rect(20, 625, 90, 20)).string_("RES").stringColor_(fgColor).font_(Font("Monaco", 10));
        resSlider = Slider(win, Rect(115, 625, 305, 20)).background_(Color.new255(40, 40, 50)).knobColor_(fgColor).value_(0.3)
            .action_({ |sl| currentRes = sl.value.linlin(0, 1, 1.0, 0.05); if(synth.notNil, { synth.set(\res, currentRes); }); });

        // ============================================================
        // MIDI CC MAPPING GUI
        // ============================================================
        StaticText(win, Rect(460, 20, 120, 20)).string_("CC 70 (Sat)").stringColor_(sensorColor).font_(Font("Monaco", 10));
        cc70Menu = PopUpMenu(win, Rect(555, 20, 120, 22)).items_(mapItems).value_(ccMap[0])
            .background_(Color.new255(40, 40, 50)).stringColor_(Color.white).font_(Font("Monaco", 9))
            .action_({ |menu| ccMap[0] = menu.value; });

        StaticText(win, Rect(460, 45, 120, 20)).string_("CC 71 (Light)").stringColor_(sensorColor).font_(Font("Monaco", 10));
        cc71Menu = PopUpMenu(win, Rect(555, 45, 120, 22)).items_(mapItems).value_(ccMap[1])
            .background_(Color.new255(40, 40, 50)).stringColor_(Color.white).font_(Font("Monaco", 9))
            .action_({ |menu| ccMap[1] = menu.value; });

        // ============================================================
        // MODULATION CONTROLS
        // ============================================================
        StaticText(win, Rect(460, 510, 220, 20)).string_("-- FM / PHASE MOD --").stringColor_(fmColor).font_(Font("Monaco", 11, true));
        StaticText(win, Rect(460, 535, 90, 20)).string_("RATIO").stringColor_(fmColor).font_(Font("Monaco", 10));
        fmRatioSlider = Slider(win, Rect(555, 535, 325, 20)).background_(Color.new255(40, 40, 50)).knobColor_(fmColor).value_(ratioToSlider.(1.0))
            .action_({ |sl| currentFmRatio = sl.value.linexp(0, 1, 0.25, 8); waveDisplay.refresh; if(synth.notNil, { synth.set(\fmRatio, currentFmRatio); }); });

        StaticText(win, Rect(460, 565, 90, 20)).string_("AMOUNT").stringColor_(fmColor).font_(Font("Monaco", 10));
        fmAmountSlider = Slider(win, Rect(555, 565, 325, 20)).background_(Color.new255(40, 40, 50)).knobColor_(fmColor).value_(0)
            .action_({ |sl| currentFmAmount = sl.value.squared; waveDisplay.refresh; if(synth.notNil, { synth.set(\fmAmount, currentFmAmount); }); });

        StaticText(win, Rect(460, 595, 90, 20)).string_("FEEDBACK").stringColor_(fmColor).font_(Font("Monaco", 10));
        fmFbSlider = Slider(win, Rect(555, 595, 325, 20)).background_(Color.new255(40, 40, 50)).knobColor_(fmColor).value_(0)
            .action_({ |sl| currentFmFb = sl.value.squared * 0.12; waveDisplay.refresh; if(synth.notNil, { synth.set(\fmFeedback, currentFmFb); }); });

        StaticText(win, Rect(460, 625, 90, 20)).string_("MOD MODE").stringColor_(fmColor).font_(Font("Monaco", 10));
        modeMenu = PopUpMenu(win, Rect(555, 625, 140, 22)).items_(["FREQ FM", "PHASE PM"]).value_(1)
            .background_(Color.new255(40, 40, 50)).stringColor_(Color.white).font_(Font("Monaco", 9))
            .action_({ |menu| currentModMode = menu.value; waveDisplay.refresh; if(synth.notNil, { synth.set(\modMode, currentModMode); }); });

        // ============================================================
        // APPLY CC MAPPING
        // ============================================================
        applySensorMapping = { |mapIndex, normVal|
            var destination = ccMap[mapIndex];
            switch(destination,
                0, {}, // Off
                1, { posSlider.valueAction_(normVal); },
                2, { cutoffSlider.valueAction_(normVal); },
                3, { resSlider.valueAction_(normVal); },
                4, { fmRatioSlider.valueAction_(normVal); },
                5, { fmAmountSlider.valueAction_(normVal); },
                6, { fmFbSlider.valueAction_(normVal); },
                7, { modeMenu.valueAction_(if(normVal < 0.5, { 0 }, { 1 })); }
            );
        };

        // ============================================================
        // SYNTH START / STOP
        // ============================================================
        startSynth = {
            if(synth.isNil, {
                synth = Synth(\wtOsc, [
                    \out, ~fxBus,
                    \freq, currentFreq, \amp, 0.25, \pos, currentPos, \cutoff, currentCutoff,
                    \res, currentRes, \fmRatio, currentFmRatio, \fmAmount, currentFmAmount,
                    \fmFeedback, currentFmFb, \modMode, currentModMode
                ]);
                if(playBtn.notNil, { playBtn.value_(1); });
            });
        };

        stopSynth = {
            if(synth.notNil, {
                synth.set(\gate, 0);
                synth = nil;
                if(playBtn.notNil, { playBtn.value_(0); });
            });
        };

        // ============================================================
        // MIDI RESPONDERS
        // ============================================================
        ~noteOn = MIDIFunc.noteOn({ |vel, note, chan, src|
            {
                var sliderPos;
                currentFreq = note.midicps;

                if(synth.isNil, {
                    startSynth.();
                }, {
                    synth.set(\freq, currentFreq, \gate, 1);
                });

                if(freqSlider.notNil, {
                    sliderPos = currentFreq.explin(20, 8000, 0, 1).clip(0, 1);
                    freqSlider.value_(sliderPos);
                });

            }.defer;
        });

        ~noteOff = MIDIFunc.noteOff({ |vel, note, chan, src|
            { stopSynth.(); }.defer;
        });

        ~cc = MIDIFunc.cc({ |val, num, chan, src|
            var rawNorm = val / 127.0;
            {
                if(num == 70) {
                    var discreteCc70 = rawNorm.round(0.02); // FIXED TYPO: 0,02 -> 0.02

                    if(discreteCc70 != lastCc70) {
                        applySensorMapping.(0, discreteCc70);
                        lastCc70 = discreteCc70;
                    };
                };

                if(num == 71) {
                    var discreteVal = rawNorm.round(0.02);

                    if(discreteVal != lastCc71) {
                        applySensorMapping.(1, discreteVal);
                        lastCc71 = discreteVal;
                    };
                };
            }.defer;
        });

        // ============================================================
        // PRESETS & TOP UI
        // ============================================================
        StaticText(win, Rect(460, 655, 90, 20)).string_("PRESETS").stringColor_(fmColor).font_(Font("Monaco", 10));

        Button(win, Rect(555, 655, 70, 22)).states_([["Bell", Color.white, Color.new255(60, 80, 120)]]).font_(Font("Monaco", 9))
            .action_({ modeMenu.valueAction_(1); fmRatioSlider.valueAction_(ratioToSlider.(2.0)); fmAmountSlider.valueAction_(0.50); fmFbSlider.valueAction_(0.0); });

        Button(win, Rect(630, 655, 70, 22)).states_([["Bass", Color.white, Color.new255(60, 80, 120)]]).font_(Font("Monaco", 9))
            .action_({ modeMenu.valueAction_(0); fmRatioSlider.valueAction_(ratioToSlider.(1.0)); fmAmountSlider.valueAction_(0.35); fmFbSlider.valueAction_(0.20); });

        Button(win, Rect(705, 655, 70, 22)).states_([["Metal", Color.white, Color.new255(60, 80, 120)]]).font_(Font("Monaco", 9))
            .action_({ modeMenu.valueAction_(1); fmRatioSlider.valueAction_(ratioToSlider.(2.75)); fmAmountSlider.valueAction_(0.55); fmFbSlider.valueAction_(0.18); });

        Button(win, Rect(780, 655, 70, 22)).states_([["Off", Color.white, Color.new255(120, 60, 60)]]).font_(Font("Monaco", 9))
            .action_({ fmRatioSlider.valueAction_(ratioToSlider.(1.0)); fmAmountSlider.valueAction_(0); fmFbSlider.valueAction_(0); });

        playBtn = Button(win, Rect(20, 20, 100, 30))
            .states_([["PLAY", Color.white, Color.new255(40, 120, 40)], ["STOP", Color.white, Color.new255(160, 40, 40)]])
            .font_(Font("Monaco", 11, true))
            .action_({ |b| if(b.value == 1, { startSynth.(); }, { stopSynth.(); }); });

        StaticText(win, Rect(140, 25, 300, 20)).string_("MIDI Mappable Wavetable Synth").stringColor_(Color.new255(180, 180, 200)).font_(Font("Monaco", 10));

        // ============================================================
        // INIT
        // ============================================================
        freqSlider.valueAction_(0.3);
        stackDisplay.refresh; waveDisplay.refresh;

        // ============================================================
        // WINDOW CLOSE CLEANUP
        // ============================================================
        win.onClose_({
            stopSynth.();
            ~wtWin = nil;
        });
        "GUI Wavetable + MIDI mapping ready!".postln;

    }.defer;
});
)
