#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include "config.h"

#if STRIP_ADDRESSABLE
#include <Adafruit_NeoPixel.h>
Adafruit_NeoPixel strip(LED_COUNT, LED_PIN, NEO_GRB + NEO_KHZ800);
#endif

#define SERVICE_UUID  "91e992b2-43df-441e-9ecb-9cd5bb334ee3"
#define COMMAND_UUID  "6f101ba6-507a-40ed-a04a-52897ed36232"
#define STATUS_UUID   "b5bdcb7c-7538-49e4-a116-89a521331c4c"

const uint8_t COOL_R = 200, COOL_G = 225, COOL_B = 255;

float    maxDuty       = 1.0f;

bool     rampActive     = false;
uint32_t rampStartMs    = 0;
uint32_t rampDurationMs = 0;
uint8_t  currentLevel   = 0;

bool     holding      = false;

BLECharacteristic *statusChar = nullptr;

static void computePowerCap() {
#if STRIP_ADDRESSABLE
  const float colorFraction = (COOL_R + COOL_G + COOL_B) / (3.0f * 255.0f);
  const float perPixelMa = 60.0f * colorFraction;
  const float cap = (float)STRIP_BUDGET_MA / (LED_COUNT * perPixelMa);
  maxDuty = cap < 1.0f ? cap : 1.0f;
#else
  maxDuty = 1.0f;
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
    if (p >= 0) ledcAttach(p, 5000, 8);
  }
#endif
}

void lightWrite(uint8_t level) {
  currentLevel = level;
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

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *server) override {
    Serial.println("phone connected");
  }
  void onDisconnect(BLEServer *server) override {
    Serial.println("phone disconnected — advertising again");
    BLEDevice::startAdvertising();
  }
};

void setup() {
  Serial.begin(115200);
  delay(300);
  lightBegin();
  lightWrite(0);
  Serial.printf("power cap: %.0f%% duty (~%.0f%% perceived) for %d px on a %d mA budget\n",
                maxDuty * 100.0f, powf(maxDuty, 1.0f / 2.2f) * 100.0f,
                LED_COUNT, STRIP_BUDGET_MA);

  BLEDevice::init(DEVICE_NAME);
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
      holding = true;
      publishStatus();
    } else {
      lightWrite((uint8_t)(255.0f * elapsed / rampDurationMs));
    }
  }
  delay(20);
}
