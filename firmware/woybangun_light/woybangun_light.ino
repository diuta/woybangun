// woybangun_light — ESP32-C6 wake light, over Bluetooth LE.
//
// Ramps a cool-white LED strip from dark to full over the hour before the alarm, so the
// light climbs alongside the app's dawn audio.
//
// Why BLE and not Wi-Fi: managed networks (co-living, hotels, offices) commonly run a
// stateful per-client filter, so a phone cannot open a connection *to* a device on the
// network even when both are joined to it. BLE has no router in the path at all, so it
// works anywhere the phone is in the room.
//
// The ramp runs here, not on the phone: the app sends one command at T-60, and the strip
// finishes the climb on its own even if the phone wanders off or Bluetooth drops.
//
// Commands, written as plain text to the command characteristic:
//   ramp:3600   ramp dark -> full over N seconds
//   on:200      set brightness now, 0-255 (for checking wiring)
//   off         off
// The status characteristic reads back as: "<state> level=<n> max_duty=<f>"

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include "config.h"

#if STRIP_ADDRESSABLE
#include <Adafruit_NeoPixel.h>
Adafruit_NeoPixel strip(LED_COUNT, LED_PIN, NEO_GRB + NEO_KHZ800);
#endif

// Generated once and shared with the iOS app — these must match LightController.swift.
#define SERVICE_UUID  "91e992b2-43df-441e-9ecb-9cd5bb334ee3"
#define COMMAND_UUID  "6f101ba6-507a-40ed-a04a-52897ed36232"
#define STATUS_UUID   "b5bdcb7c-7538-49e4-a116-89a521331c4c"

// Cool white, ~6000K. Blue-weighted on purpose: cool light suppresses melatonin, which is
// the whole reason for waking to it.
const uint8_t COOL_R = 200, COOL_G = 225, COOL_B = 255;

// Ceiling on the duty cycle, worked out at boot from LED_COUNT and STRIP_BUDGET_MA.
float    maxDuty       = 1.0f;

bool     rampActive     = false;
uint32_t rampStartMs    = 0;
uint32_t rampDurationMs = 0;
uint8_t  currentLevel   = 0;

// After the ramp reaches full the strip holds, then switches itself off — otherwise a
// missed "off" leaves it burning all day once you've left the house.
bool     holding      = false;
uint32_t holdStartMs  = 0;
const uint32_t HOLD_MS = 30UL * 60UL * 1000UL;   // 30 minutes

BLECharacteristic *statusChar = nullptr;

// ── LED output ──────────────────────────────────────────────────────────────

// A WS2812B pixel is three ~20 mA dies, so ~60 mA at full white. Our cool white sits a
// little under full, which buys back some headroom.
static void computePowerCap() {
#if STRIP_ADDRESSABLE
  const float colorFraction = (COOL_R + COOL_G + COOL_B) / (3.0f * 255.0f);
  const float perPixelMa = 60.0f * colorFraction;
  const float cap = (float)STRIP_BUDGET_MA / (LED_COUNT * perPixelMa);
  maxDuty = cap < 1.0f ? cap : 1.0f;
#else
  maxDuty = 1.0f;   // analog strips have their own supply behind the MOSFETs
#endif
}

void lightBegin() {
  computePowerCap();
#if STRIP_ADDRESSABLE
  strip.begin();
  strip.clear();
  strip.show();
#elif STRIP_ANALOG_PWM
  const int pins[3] = {PIN_R, PIN_G, PIN_B};
  for (int p : pins) {
    if (p >= 0) ledcAttach(p, 5000, 8);   // 5 kHz, 8-bit — above flicker perception
  }
#endif
}

// `level` is perceptual: 0 is off, 255 is full. Gamma and the power cap are applied here.
void lightWrite(uint8_t level) {
  currentLevel = level;
  // Perceived brightness goes roughly as duty^(1/2.2), so raise to 2.2 to make the ramp
  // look linear instead of rushing at the start and flattening out.
  float t = level / 255.0f;
  float duty = powf(t, 2.2f) * maxDuty;

#if STRIP_ADDRESSABLE
  strip.setBrightness(255);
  uint8_t r = (uint8_t)(COOL_R * duty);
  uint8_t g = (uint8_t)(COOL_G * duty);
  uint8_t b = (uint8_t)(COOL_B * duty);
  for (int i = 0; i < LED_COUNT; i++) strip.setPixelColor(i, strip.Color(r, g, b));
  strip.show();
#elif STRIP_ANALOG_PWM
  if (PIN_R >= 0) ledcWrite(PIN_R, (uint32_t)(COOL_R * duty));
  if (PIN_G >= 0) ledcWrite(PIN_G, (uint32_t)(COOL_G * duty));
  if (PIN_B >= 0) ledcWrite(PIN_B, (uint32_t)(COOL_B * duty));
#endif
}

// ── Commands ────────────────────────────────────────────────────────────────

void publishStatus() {
  const char *state = rampActive ? "ramping" : (holding ? "holding" : "idle");
  char body[96];
  snprintf(body, sizeof(body), "%s level=%u max_duty=%.3f", state, currentLevel, maxDuty);
  if (statusChar) statusChar->setValue(body);
}

void handleCommand(const String &raw) {
  String cmd = raw;
  cmd.trim();
  Serial.printf("command: %s\n", cmd.c_str());

  if (cmd.startsWith("ramp:")) {
    long seconds = cmd.substring(5).toInt();
    if (seconds < 1) seconds = 1;
    rampDurationMs = (uint32_t)seconds * 1000UL;
    rampStartMs = millis();
    rampActive = true;
    holding = false;
    lightWrite(0);
    Serial.printf("ramp started over %lds\n", seconds);
  } else if (cmd.startsWith("on:")) {
    long level = cmd.substring(3).toInt();
    rampActive = false;
    holding = false;
    lightWrite((uint8_t)constrain(level, 0, 255));
  } else if (cmd == "off") {
    rampActive = false;
    holding = false;
    lightWrite(0);
  } else {
    Serial.println("unknown command");
  }
  publishStatus();
}

class CommandCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *characteristic) override {
    handleCommand(String(characteristic->getValue().c_str()));
  }
};

// Keep advertising after a disconnect, so the phone can always find us again.
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *server) override {
    Serial.println("phone connected");
  }
  void onDisconnect(BLEServer *server) override {
    Serial.println("phone disconnected — advertising again");
    BLEDevice::startAdvertising();
  }
};

// ── Setup ───────────────────────────────────────────────────────────────────

void setup() {
  Serial.begin(115200);
  delay(300);
  lightBegin();
  lightWrite(0);
  Serial.printf("power cap: %.0f%% duty (~%.0f%% perceived) for %d px on a %d mA budget\n",
                maxDuty * 100.0f, powf(maxDuty, 1.0f / 2.2f) * 100.0f,
                LED_COUNT, STRIP_BUDGET_MA);

  BLEDevice::init(DEVICE_NAME);                  // the name the phone advertises/scans for
  BLEServer *server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());

  BLEService *service = server->createService(SERVICE_UUID);

  BLECharacteristic *commandChar = service->createCharacteristic(
    COMMAND_UUID, BLECharacteristic::PROPERTY_WRITE);
  commandChar->setCallbacks(new CommandCallbacks());

  statusChar = service->createCharacteristic(
    STATUS_UUID, BLECharacteristic::PROPERTY_READ);
  publishStatus();

  service->start();

  BLEAdvertising *advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(SERVICE_UUID);
  advertising->setScanResponse(true);
  BLEDevice::startAdvertising();

  Serial.printf("advertising as \"%s\", service %s\n", DEVICE_NAME, SERVICE_UUID);
}

void loop() {
  if (rampActive) {
    uint32_t elapsed = millis() - rampStartMs;
    if (elapsed >= rampDurationMs) {
      lightWrite(255);
      rampActive = false;
      holding = true;                        // full brightness as the alarm fires
      holdStartMs = millis();
      publishStatus();
    } else {
      lightWrite((uint8_t)(255.0f * elapsed / rampDurationMs));
    }
  } else if (holding && millis() - holdStartMs >= HOLD_MS) {
    holding = false;
    lightWrite(0);
    publishStatus();
    Serial.println("hold expired — light off");
  }
  delay(20);
}
