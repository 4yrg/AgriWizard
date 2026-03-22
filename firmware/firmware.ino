#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <DHT.h>
#include <ArduinoJson.h>

const char* WIFI_SSID = "Redmi 14C";
const char* WIFI_PASSWORD = "Variable557";

const char* MQTT_HOST = "0844c36e03374e7682f81036bb673d45.s1.eu.hivemq.cloud";
const uint16_t MQTT_PORT = 8883;
const char* MQTT_USERNAME = "Hasintha";
const char* MQTT_PASSWORD = "Agriwizard@999";

const char* DEVICE_ID = "esp32-greenhouse-01";

const char* SENSOR_ID = "REPLACE_WITH_SENSOR_ID_FROM_HARDWARE_SERVICE";
const char* FAN_EQUIPMENT_ID = "a59110c3-cd56-4c83-9626-0b34b3cdd19d";
const char* PUMP_EQUIPMENT_ID = "REPLACE_WITH_PUMP_EQUIPMENT_ID";

const char* PARAM_TEMP = "air_temp_c";
const char* PARAM_HUMIDITY = "air_humidity_pct";
const char* PARAM_SOIL = "soil_moisture_pct";

const int DHT_PIN = 4;
const int DHT_TYPE = DHT11;
const int SOIL_PIN = 34;
const int FAN_PIN = 18;
const int PUMP_PIN = 19;

const unsigned long TELEMETRY_INTERVAL_MS = 30000;

WiFiClientSecure espClient;
PubSubClient mqttClient(espClient);
DHT dht(DHT_PIN, DHT_TYPE);

unsigned long lastTelemetryMs = 0;

String commandTopicWildcard = "agriwizard/equipment/+/command";
String sensorTelemetryTopic = "";
String fanCommandTopic = "";
String pumpCommandTopic = "";
String fanStatusTopic = "";
String pumpStatusTopic = "";

bool fanOn = false;
bool pumpOn = false;

void logLine(const String& message) {
  Serial.println("[FW] " + message);
}

void setFan(bool on) {
  fanOn = on;
  if (on) {
    pinMode(FAN_PIN, OUTPUT);//turn on fan
  } else {
    pinMode(FAN_PIN, INPUT); //turn off fan
  }
  logLine(String("FAN -> ") + (on ? "ON" : "OFF")); 
}

void setPump(bool on) {
  pumpOn = on;
  if (on){
    pinMode(PUMP_PIN,OUTPUT); //turn on pump
  }
  else{
    pinMode(PUMP_PIN,INPUT); //turn off pump
  }
  logLine(String("PUMP -> ") + (on ? "ON" : "OFF"));
}

bool operationMeansOn(const String& operation) {
  String op = operation;
  op.toUpperCase();
  return op == "ON" || op == "TURN_ON" || op == "START" || op == "ENABLE";
}

bool operationMeansOff(const String& operation) {
  String op = operation;
  op.toUpperCase();
  return op == "OFF" || op == "TURN_OFF" || op == "STOP" || op == "DISABLE";
}

void publishEquipmentStatus(const String& statusTopic, const char* equipmentId, bool isOn) {
  StaticJsonDocument<160> doc;
  doc["equipment_id"] = equipmentId;
  doc["status"] = isOn ? "ON" : "OFF";

  char payload[192];
  size_t n = serializeJson(doc, payload, sizeof(payload));
  bool ok = mqttClient.publish(statusTopic.c_str(), payload, n, false);
  logLine(String("status publish ") + (ok ? "OK" : "FAIL") + " topic=" + statusTopic + " payload=" + String(payload));
}

String equipmentIdFromTopic(const String& topic) {
  String prefix = "agriwizard/equipment/";
  String suffix = "/command";
  if (!topic.startsWith(prefix) || !topic.endsWith(suffix)) {
    return "";
  }

  int start = prefix.length();
  int end = topic.length() - suffix.length();
  if (end <= start) {
    return "";
  }
  return topic.substring(start, end);
}

void handleCommand(const String& topic, const String& payload) {
  String equipmentId = equipmentIdFromTopic(topic);
  if (equipmentId.length() == 0) {
    logLine("ignored command: invalid topic=" + topic);
    return;
  }

  logLine("cmd topic=" + topic + " payload=" + payload);

  StaticJsonDocument<512> doc;
  DeserializationError err = deserializeJson(doc, payload);
  if (err) {
    logLine("ignored command: json parse failed");
    return;
  }

  String op = doc["operation"] | "";
  if (op.length() == 0) {
    logLine("ignored command: missing operation");
    return;
  }

  bool turnOn = operationMeansOn(op);
  bool turnOff = operationMeansOff(op);
  if (!turnOn && !turnOff) {
    logLine("ignored command: unsupported operation=" + op);
    return;
  }

  if (equipmentId == FAN_EQUIPMENT_ID) {
    setFan(turnOn && !turnOff);
    publishEquipmentStatus(fanStatusTopic, FAN_EQUIPMENT_ID, fanOn);
    return;
  }

  if (equipmentId == PUMP_EQUIPMENT_ID) {
    setPump(turnOn && !turnOff);
    publishEquipmentStatus(pumpStatusTopic, PUMP_EQUIPMENT_ID, pumpOn);
    return;
  }

  logLine("ignored command: unknown equipment_id=" + equipmentId);
}

float readSoilMoisturePct() {
  const int dryRaw = 3200;
  const int wetRaw = 1200;
  int raw = analogRead(SOIL_PIN);
  float pct = 100.0f * (float)(dryRaw - raw) / (float)(dryRaw - wetRaw);
  if (pct < 0.0f) pct = 0.0f;
  if (pct > 100.0f) pct = 100.0f;
  return pct;
}

void publishTelemetry() {
  float humidity = dht.readHumidity();
  float temperature = dht.readTemperature();
  float soilPct = readSoilMoisturePct();

  if (isnan(humidity) || isnan(temperature)) {
    logLine("telemetry skipped: DHT read failed");
    return;
  }

  StaticJsonDocument<512> doc;
  doc["sensor_id"] = SENSOR_ID;

  JsonArray readings = doc.createNestedArray("readings");
  JsonObject r1 = readings.createNestedObject();
  r1["parameter_id"] = PARAM_TEMP;
  r1["value"] = temperature;

  JsonObject r2 = readings.createNestedObject();
  r2["parameter_id"] = PARAM_HUMIDITY;
  r2["value"] = humidity;

  JsonObject r3 = readings.createNestedObject();
  r3["parameter_id"] = PARAM_SOIL;
  r3["value"] = soilPct;

  char payload[640];
  size_t n = serializeJson(doc, payload, sizeof(payload));
  bool ok = mqttClient.publish(sensorTelemetryTopic.c_str(), payload, n, false);
  logLine(String("telemetry publish ") + (ok ? "OK" : "FAIL") + " topic=" + sensorTelemetryTopic + " payload=" + String(payload));
}

void mqttCallback(char* topic, byte* message, unsigned int length) {
  String topicStr(topic);
  String payload;
  payload.reserve(length + 1);
  for (unsigned int i = 0; i < length; i++) {
    payload += (char)message[i];
  }

  handleCommand(topicStr, payload);
}

void connectWiFi() {
  WiFi.mode(WIFI_STA);
  logLine("connecting WiFi...");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  while (WiFi.status() != WL_CONNECTED) {
    Serial.print(".");
    delay(600);
  }
  Serial.println();
  logLine("WiFi connected, IP=" + WiFi.localIP().toString());
}

void connectMQTT() {
  mqttClient.setServer(MQTT_HOST, MQTT_PORT);
  mqttClient.setCallback(mqttCallback);

  while (!mqttClient.connected()) {
    logLine("connecting MQTT...");
    bool ok;
    if (strlen(MQTT_USERNAME) > 0) {
      ok = mqttClient.connect(DEVICE_ID, MQTT_USERNAME, MQTT_PASSWORD);
    } else {
      ok = mqttClient.connect(DEVICE_ID);
    }

    if (ok) {
      logLine("MQTT connected");
      mqttClient.subscribe(commandTopicWildcard.c_str(), 1);
      logLine("subscribed topic=" + commandTopicWildcard);
      publishEquipmentStatus(fanStatusTopic, FAN_EQUIPMENT_ID, fanOn);
      publishEquipmentStatus(pumpStatusTopic, PUMP_EQUIPMENT_ID, pumpOn);
    } else {
      logLine(String("MQTT connect failed, rc=") + mqttClient.state());
      delay(1500);
    }
  }
}

void setupTopics() {
  sensorTelemetryTopic = "agriwizard/sensor/" + String(SENSOR_ID) + "/telemetry";
  fanCommandTopic = "agriwizard/equipment/" + String(FAN_EQUIPMENT_ID) + "/command";
  pumpCommandTopic = "agriwizard/equipment/" + String(PUMP_EQUIPMENT_ID) + "/command";
  fanStatusTopic = fanCommandTopic + "/status";
  pumpStatusTopic = pumpCommandTopic + "/status";
}

void setup() {
  Serial.begin(115200);
  delay(200);
  logLine("booting...");

  pinMode(FAN_PIN, OUTPUT);
  pinMode(PUMP_PIN, OUTPUT);
  setFan(false);
  setPump(false);

  analogReadResolution(12);
  dht.begin();

  setupTopics();
  logLine("sensor topic=" + sensorTelemetryTopic);
  logLine("fan command topic=" + fanCommandTopic);
  logLine("pump command topic=" + pumpCommandTopic);
  connectWiFi();

  espClient.setInsecure(); // Skips certificate validation but allows the TLS handshake
  connectMQTT();
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    logLine("WiFi disconnected, reconnecting");
    connectWiFi();
  }

  if (!mqttClient.connected()) {
    logLine("MQTT disconnected, reconnecting");
    connectMQTT();
  }

  mqttClient.loop();

  unsigned long now = millis();
  if (now - lastTelemetryMs >= TELEMETRY_INTERVAL_MS) {
    lastTelemetryMs = now;
    publishTelemetry();
  }
}
