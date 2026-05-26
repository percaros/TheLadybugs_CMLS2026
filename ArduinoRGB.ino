#include <Wire.h>
#include "Adafruit_TCS34725.h"

// ==========================================
// RAW CALIBRATION VARIABLES
// ==========================================
// 1. RAW values for Pure Black Ink:
const int RAW_BLACK_R = 281;
const int RAW_BLACK_G = 384;
const int RAW_BLACK_B = 530;

// 2. RAW values for Pure White Paper:
const int RAW_WHITE_R = 4142;
const int RAW_WHITE_G = 6211;
const int RAW_WHITE_B = 8588;
// ==========================================

const int buttonPin = 2; 
const int ledPin = 13;   

// Variable to track the synth gate state (1 = pressed, 0 = released)
int synthGate = 0; 

// Medium configuration (Ideal balance for light and dark)
Adafruit_TCS34725 tcs = Adafruit_TCS34725(TCS34725_INTEGRATIONTIME_24MS, TCS34725_GAIN_4X);

void setup() {
  Serial.begin(9600);
  
  pinMode(ledPin, OUTPUT);
  pinMode(buttonPin, INPUT);

  // We comment out the setup print so it doesn't send garbage to JUCE on startup
  // Serial.println("Starting RAW Scanner for JUCE...");

  if (!tcs.begin()) {
    // Serial.println("Error: TCS34725 sensor not found.");
    while (1); 
  }
}

void loop() {
  // Read the button state
  int currentButtonState = digitalRead(buttonPin);

  // Map the button state to a Synth Gate (LOW = pressed = 1, HIGH = released = 0)
  if (currentButtonState == LOW) {
    synthGate = 0;
    digitalWrite(ledPin, LOW); // Turn on LED (Active LOW in your wiring)
  } else {
    synthGate = 1;
    digitalWrite(ledPin, HIGH); // Turn off LED
  }

  // Continuously scan and stream data to JUCE
  scanColorRAW();       
}

void scanColorRAW() {
  uint16_t r_raw, g_raw, b_raw, c_raw;

  // 1. READ RAW DATA DIRECTLY
  tcs.getRawData(&r_raw, &g_raw, &b_raw, &c_raw);

  // 2. DIRECT LINEAR MAPPING (Preserves luminance)
  int calRed = map(r_raw, RAW_BLACK_R, RAW_WHITE_R, 0, 255);
  int calGreen = map(g_raw, RAW_BLACK_G, RAW_WHITE_G, 0, 255);
  int calBlue = map(b_raw, RAW_BLACK_B, RAW_WHITE_B, 0, 255);

  // CONSTRAIN TO 0-255 RANGE
  calRed = constrain(calRed, 0, 255);
  calGreen = constrain(calGreen, 0, 255);
  calBlue = constrain(calBlue, 0, 255);

// 3. HYBRID CONVERSION: HSV Saturation + HSL Lightness
  float r_norm = calRed / 255.0;
  float g_norm = calGreen / 255.0;
  float b_norm = calBlue / 255.0;

  float cmax = max(r_norm, max(g_norm, b_norm));
  float cmin = min(r_norm, min(g_norm, b_norm));
  float delta = cmax - cmin;

  float h = 0.0;
  float s_hybrid = 0.0; // HSV Saturation (keeps dark colors saturated)
  float l = 0.0;        // HSL Lightness (tracks true brightness)
  
  // Calculate HSL Lightness
  l = (cmax + cmin) / 2.0;

  // Calculate HSV Saturation
  if (cmax > 0.0) {
    s_hybrid = delta / cmax; 
  } else {
    s_hybrid = 0.0;
  }

  // Calculate Hue
  if (delta != 0.0) {
    if (cmax == r_norm) {
      h = (g_norm - b_norm) / delta;
      while (h >= 6.0) h -= 6.0;
      while (h < 0.0) h += 6.0;
    } else if (cmax == g_norm) {
      h = ((b_norm - r_norm) / delta) + 2.0;
    } else {
      h = ((r_norm - g_norm) / delta) + 4.0;
    }
    h /= 6.0;
    if (h < 0.0) h += 1.0;
  }

  // 4. SEND DATA TO JUCE
  // Format: hue,sat,light,buttonState\n
  Serial.print(h, 4);
  Serial.print(",");
  Serial.print(s_hybrid, 4);
  Serial.print(",");
  Serial.print(l, 4);
  Serial.print(",");
  Serial.println(synthGate);

  // The sensor integration time takes ~24ms automatically, 
  // so we don't need a heavy manual delay here. A tiny 5ms buffer keeps things stable.
  delay(5);
}