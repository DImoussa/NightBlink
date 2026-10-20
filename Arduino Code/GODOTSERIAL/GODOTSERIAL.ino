// Manette aimant + gyroscope LSM6DS3 <-> Godot (autoloads ArduinoManager + Arduino)
// Bouton AVANCER : pin 8 et GND
// Bouton AIMANT  : pin 7 et GND
// LED aimant : pin 13 ; LEDs lampe : verte pin 2, orange pin 4, rouge pin 12
// Gyroscope I2C (BMI160 / MPU / LSM6DS3) : VIN -> 5V, GND -> GND, SCL -> A5, SDA -> A4 (CS, SAD, OCS, INT1, INT2, SCX, SDX non branchés)
//
// Envoie : FWD:1/0, MAG:1/0, imu:<pitch>,<roll> (angles en degrés), imu:err + i2c:<adresses> si le capteur est absent, imu:type:<n> à la connexion
// Reçoit : DISCOVER (pairing avec Godot), L1 / L0 (LED aimant), energy:0..3 (LEDs de la lampe)
// Librairie : Wire (incluse avec l'IDE Arduino, rien à installer)

#include <Wire.h>

const int PIN_BTN_FORWARD = 8;
const int PIN_BTN_MAGNET  = 7;
const int PIN_LED_GREEN   = 13;
const int LED_VERTE_LAMPE_PIN  = 2;
const int LED_ORANGE_LAMPE_PIN = 4;
const int LED_ROUGE_LAMPE_PIN  = 12;

const unsigned long DEBOUNCE_MS = 20;
const unsigned long IMU_PERIODE_MS = 20;   // 50 mesures par seconde

bool forwardPressed = false;
bool magnetPressed  = false;
unsigned long forwardLastChange = 0;
unsigned long magnetLastChange  = 0;

// ── Gyroscope (I2C) : BMI160, MPU-6050/6500/9250 ou LSM6DS3, détecté automatiquement ──
byte imuAdresse = 0;         // 0 = pas trouvé
byte imuType = 0;            // 1 = BMI160, 2 = MPU-60x0/65x0/9250, 3 = LSM6DS3
float gyroEchelle = 1;       // conversion en °/s
float pitch = 0, roll = 0;   // angles filtrés (degrés)
float pitchEnvoye = 999, rollEnvoye = 999;
unsigned long dernierImu = 0;

void ecrireRegistre(byte reg, byte valeur) {
  Wire.beginTransmission(imuAdresse);
  Wire.write(reg);
  Wire.write(valeur);
  Wire.endTransmission();
}

int lireRegistre(byte adresse, byte reg) {
  Wire.beginTransmission(adresse);
  Wire.write(reg);
  if (Wire.endTransmission(false) != 0) return -1;
  if (Wire.requestFrom(adresse, (byte)1) != 1) return -1;
  return Wire.read();
}

bool trouverImu() {
  byte adresses[] = {0x68, 0x69, 0x6A, 0x6B};
  for (byte a : adresses) {
    lireRegistre(a, 0x7F);                     // lecture à vide : le BMI160 rate la 1re lecture après l'allumage
    int idBmi = lireRegistre(a, 0x00);
    int idMpu = lireRegistre(a, 0x75);
    int idLsm = lireRegistre(a, 0x0F);
    imuAdresse = a;
    if (idBmi == 0xD1) {                       // BMI160
      imuType = 1;
      ecrireRegistre(0x7E, 0x11); delay(50);   // accéléro en mode normal (±2 g)
      ecrireRegistre(0x7E, 0x15); delay(100);  // gyro en mode normal (±2000 °/s)
      gyroEchelle = 1.0 / 16.4;
      return true;
    }
    if (idMpu == 0x68 || idMpu == 0x70 || idMpu == 0x71 || idMpu == 0x73) {  // MPU-6050, 6500, 9250, 9255
      imuType = 2;
      ecrireRegistre(0x6B, 0x00); delay(50);   // sort du mode veille (gyro ±250 °/s, accéléro ±2 g)
      gyroEchelle = 1.0 / 131.0;
      return true;
    }
    if (idLsm == 0x69 || idLsm == 0x6A || idLsm == 0x6C) {  // LSM6DS3, LSM6DS3TR-C, LSM6DSO
      imuType = 3;
      ecrireRegistre(0x10, 0x40);              // accéléro : 104 Hz, ±2 g
      ecrireRegistre(0x11, 0x44);              // gyro : 104 Hz, ±500 °/s
      ecrireRegistre(0x12, 0x44);
      gyroEchelle = 0.0175;
      return true;
    }
  }
  imuAdresse = 0;
  return false;
}

// Lit n valeurs 16 bits à partir de reg (petit-boutiste sauf MPU)
bool lireBloc(byte reg, int16_t *v, int n, bool grandBoutiste) {
  Wire.beginTransmission(imuAdresse);
  Wire.write(reg);
  if (Wire.endTransmission(false) != 0) return false;
  if (Wire.requestFrom(imuAdresse, (byte)(n * 2)) != n * 2) return false;
  for (int i = 0; i < n; i++) {
    byte b1 = Wire.read(), b2 = Wire.read();
    v[i] = grandBoutiste ? (int16_t)(b1 << 8 | b2) : (int16_t)(b2 << 8 | b1);
  }
  return true;
}

void lireImu() {
  int16_t g[3], acc[3];
  if (imuType == 2) {
    int16_t v[7];                              // accéléro X,Y,Z, température, gyro X,Y,Z
    if (!lireBloc(0x3B, v, 7, true)) return;
    int16_t v2[3];
    if (!lireBloc(0x43, v2, 3, true)) return;
    for (int i = 0; i < 3; i++) { acc[i] = v[i]; g[i] = v2[i]; }
  } else {
    int16_t v[6];                              // gyro X,Y,Z puis accéléro X,Y,Z
    if (!lireBloc(imuType == 1 ? 0x0C : 0x22, v, 6, false)) return;
    for (int i = 0; i < 3; i++) { g[i] = v[i]; acc[i] = v[i + 3]; }
  }
  float gx = g[0] * gyroEchelle, gy = g[1] * gyroEchelle;   // °/s
  float ax = acc[0], ay = acc[1], az = acc[2];            // l'échelle n'importe pas pour les angles

  float pitchAcc = atan2(-ax, sqrt(ay * ay + az * az)) * 180.0 / PI;
  float rollAcc  = atan2(ay, az) * 180.0 / PI;
  float dt = IMU_PERIODE_MS / 1000.0;
  // Filtre complémentaire : le gyro pour la réactivité, l'accéléro pour ne pas dériver
  pitch = 0.96 * (pitch + gy * dt) + 0.04 * pitchAcc;
  roll  = 0.96 * (roll  + gx * dt) + 0.04 * rollAcc;
}

// Diagnostic : liste les appareils I2C vus sur A4/A5 ("i2c:aucun" si rien n'est branché)
void scannerI2C() {
  bool trouve = false;
  for (byte a = 1; a < 127; a++) {
    Wire.beginTransmission(a);
    if (Wire.endTransmission() == 0) {
      Serial.print("i2c:0x");
      Serial.println(a, HEX);
      trouve = true;
    }
  }
  if (!trouve) Serial.println("i2c:aucun");
}

void setup() {
  Serial.begin(115200);
  Serial.setTimeout(10);
  pinMode(PIN_BTN_FORWARD, INPUT_PULLUP);
  pinMode(PIN_BTN_MAGNET, INPUT_PULLUP);
  pinMode(PIN_LED_GREEN, OUTPUT);
  pinMode(LED_VERTE_LAMPE_PIN, OUTPUT);
  pinMode(LED_ORANGE_LAMPE_PIN, OUTPUT);
  pinMode(LED_ROUGE_LAMPE_PIN, OUTPUT);
  Wire.begin();
  Wire.setWireTimeout(3000, true);           // ne bloque jamais la carte si le gyro est mal branché
  trouverImu();
  Serial.println("READY");
}

void checkButton(int pin, bool &state, unsigned long &lastChange, const char *name) {
  bool pressed = (digitalRead(pin) == LOW);
  if (pressed != state && millis() - lastChange > DEBOUNCE_MS) {
    state = pressed;
    lastChange = millis();
    Serial.print(name);
    Serial.print(':');
    Serial.println(pressed ? 1 : 0);
  }
}

void loop() {
  checkButton(PIN_BTN_FORWARD, forwardPressed, forwardLastChange, "FWD");
  checkButton(PIN_BTN_MAGNET, magnetPressed, magnetLastChange, "MAG");

  if (Serial.available()) {
    String msg = Serial.readStringUntil('\n');
    msg.trim();
    if (msg == "DISCOVER") {
      Serial.println("GDSERIAL_ACK:arduino_uno");
      if (imuAdresse != 0) { Serial.print("imu:type:"); Serial.println(imuType); }
      digitalWrite(PIN_LED_GREEN, HIGH);     // LED aimant allumée = connectée à Godot
      if (imuAdresse == 0 && !trouverImu()) {
        Serial.println("imu:err");
        scannerI2C();
      }
      pitchEnvoye = 999;                     // renvoie les angles tout de suite
    }
    else if (msg == "L1") digitalWrite(PIN_LED_GREEN, HIGH);
    else if (msg == "L0") digitalWrite(PIN_LED_GREEN, LOW);
    else if (msg.startsWith("energy:")) {
      int niveau = msg.substring(7).toInt(); // 3 = pleine, 0 = vide
      digitalWrite(LED_VERTE_LAMPE_PIN, niveau >= 3 ? HIGH : LOW);
      digitalWrite(LED_ORANGE_LAMPE_PIN, niveau >= 2 ? HIGH : LOW);
      digitalWrite(LED_ROUGE_LAMPE_PIN, niveau >= 1 ? HIGH : LOW);
    }
  }

  if (imuAdresse != 0 && millis() - dernierImu >= IMU_PERIODE_MS) {
    dernierImu = millis();
    lireImu();
    // N'envoie que si l'angle a bougé d'au moins 1°
    if (abs(pitch - pitchEnvoye) >= 1 || abs(roll - rollEnvoye) >= 1) {
      pitchEnvoye = pitch;
      rollEnvoye = roll;
      Serial.print("imu:");
      Serial.print(pitch, 1);
      Serial.print(',');
      Serial.println(roll, 1);
    }
  }
}
