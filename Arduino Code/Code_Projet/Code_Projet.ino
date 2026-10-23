// Manette NighBlink (aimant + lampe) <-> Godot (autoloads ArduinoManager + Arduino, voir arduino.gd)
//
// Carte -> Godot (115200 bauds, une ligne par message) :
//   GDSERIAL_ACK:arduino_uno     réponse à DISCOVER (appairage)
//   FWD:1 / FWD:0                bouton AVANCER (pin 8) appuyé / relâché
//   MAG:1 / MAG:0                bouton AIMANT  (pin 7) appuyé / relâché
//   imu:<pitch>,<roll>,<yaw>     angles en degrés du gyroscope (BMI160 ou LSM6DS3), envoyés quand ils changent
//                                torche : roll = lever/baisser, yaw = tourner à gauche/droite (pitch = vriller)
//   imu:BMI160 @0x68 / imu:err   au démarrage : gyroscope trouvé / pas trouvé
// Godot -> carte :
//   DISCOVER                     appairage
//   energy:0..3                  énergie de la lampe : 3 = verte + orange + rouge, 0 = tout éteint
//   L1 / L0                      aimant actif / inactif (la LED de l'aimant clignote quand il est actif)
//
// Branchements : boutons entre la pin et GND (pull-up interne), gyroscope SDA -> A4, SCL -> A5.
// Important : la boucle ne doit jamais attendre (pas de delay), sinon les boutons et le gyroscope sont ratés.

#include <Wire.h>

bool boutonAvant = false;   // Etat du bouton avancer au dernier envoi
bool boutonAimant = false;  // Etat du bouton aimant au dernier envoi
unsigned long dernierChangementAvant = 0;
unsigned long dernierChangementAimant = 0;
bool appaire = false;       // Devient true quand Godot a envoyé DISCOVER
bool aimantActif = false;   // Envoyé par Godot (L1 / L0)

const int LED_AIMANT_PIN = 13;
const int LED_ROUGE_LAMPE_PIN = 12;
const int LED_ORANGE_LAMPE_PIN = 4;
const int LED_VERTE_LAMPE_PIN = 2;

const int BTN_AIMANT_AVANCER_PIN = 8;
const int BTN_AIMANT_ACTIVER_PIN = 7;

const unsigned long ANTI_REBOND_MS = 25;
const unsigned long CLIGNOTEMENT_MS = 150;  // LED de l'aimant quand il est actif

const unsigned long IMU_PERIODE_MS = 20;    // 50 mesures par seconde
const float IMU_SEUIL_ENVOI = 0.3;          // degrés : en dessous, on n'envoie rien (évite le bruit)

enum TypeImu { AUCUNE, BMI160, LSM6DS3 };
TypeImu typeImu = AUCUNE;
byte imuAdresse = 0;
byte regDonnees = 0;
float echelleGyro = 0;
float pitch = 0, roll = 0, yaw = 0;      // roll = lever/baisser la torche, yaw = tourner à gauche/droite
float pitchEnvoye = 999, rollEnvoye = 999, yawEnvoye = 999;
float biaisX = 0, biaisY = 0, biaisZ = 0; // dérive du gyroscope (°/s), mesurée quand la torche est immobile
const float SEUIL_IMMOBILE = 2.0;         // °/s : en dessous sur les 3 axes, la torche est considérée immobile
const unsigned long DUREE_IMMOBILE_MS = 500; // ... mais seulement après ce temps : une rotation lente est quand même comptée
unsigned long debutCalme = 0;
unsigned long dernierImu = 0;
bool imuPremiereMesure = true;
unsigned long derniereRecherche = 0;      // gyroscope absent : on le recherche toutes les secondes
byte echecsLecture = 0;                   // lectures ratées d'affilée (fil débranché ?)

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
  // BMI160 : identifiant 0xD1
  byte adressesBmi[] = {0x68, 0x69};
  for (byte a : adressesBmi) {
    if (lireRegistre(a, 0x00) != 0xD1) continue;
    imuAdresse = a;
    typeImu = BMI160;
    ecrireRegistre(0x7E, 0xB6); delay(100);                      // reset logiciel
    for (byte essai = 0; essai < 5 && (lireRegistre(a, 0x03) & 0x30) != 0x10; essai++) {
      ecrireRegistre(0x7E, 0x11); delay(50);                      // accéléromètre en mode normal
    }
    for (byte essai = 0; essai < 5 && (lireRegistre(a, 0x03) & 0x0C) != 0x04; essai++) {
      ecrireRegistre(0x7E, 0x15); delay(100);                     // gyroscope en mode normal
    }
    ecrireRegistre(0x40, 0x28);   // accéléromètre 100 Hz
    ecrireRegistre(0x41, 0x03);   // ±2 g
    ecrireRegistre(0x42, 0x28);   // gyroscope 100 Hz
    ecrireRegistre(0x43, 0x02);   // ±500 °/s
    regDonnees = 0x0C;            // gyro X,Y,Z puis accéléro X,Y,Z
    echelleGyro = 1.0 / 65.6;
    return true;
  }

  // LSM6DS3 / LSM6DS3TR-C / LSM6DSO
  byte adressesLsm[] = {0x6A, 0x6B};
  for (byte a : adressesLsm) {
    int id = lireRegistre(a, 0x0F);
    if (id != 0x69 && id != 0x6A && id != 0x6C) continue;
    imuAdresse = a;
    typeImu = LSM6DS3;
    ecrireRegistre(0x10, 0x40);   // accéléromètre 104 Hz, ±2 g
    ecrireRegistre(0x11, 0x44);   // gyroscope 104 Hz, ±500 °/s
    ecrireRegistre(0x12, 0x44);   // lecture en bloc cohérente + adresses auto-incrémentées
    regDonnees = 0x22;            // gyro X,Y,Z puis accéléro X,Y,Z
    echelleGyro = 0.0175;
    return true;
  }
  return false;
}

void lireImu(float dt) {
  Wire.beginTransmission(imuAdresse);
  Wire.write(regDonnees);
  if (Wire.endTransmission(false) != 0 || Wire.requestFrom(imuAdresse, (byte)12) != 12) {
    // Gyroscope perdu (faux contact) : on le signale et on le recherchera
    if (++echecsLecture >= 10) {
      imuAdresse = 0;
      typeImu = AUCUNE;
      imuPremiereMesure = true;
      Serial.println("imu:err");
    }
    return;
  }
  echecsLecture = 0;
  int16_t v[6];
  for (int i = 0; i < 6; i++) {
    byte bas = Wire.read();
    v[i] = (int16_t)(Wire.read() << 8 | bas);
  }
  float gx = v[0] * echelleGyro, gy = v[1] * echelleGyro, gz = v[2] * echelleGyro;   // °/s
  float ax = v[3], ay = v[4], az = v[5];                     // l'échelle n'importe pas pour les angles

  // Dérive du gyroscope : apprise en continu tant que la torche ne bouge pas
  bool calme = abs(gx - biaisX) < SEUIL_IMMOBILE && abs(gy - biaisY) < SEUIL_IMMOBILE && abs(gz - biaisZ) < SEUIL_IMMOBILE;
  if (!calme) debutCalme = millis();
  bool immobile = calme && millis() - debutCalme >= DUREE_IMMOBILE_MS;
  if (immobile) {
    biaisX += 0.02 * (gx - biaisX);
    biaisY += 0.02 * (gy - biaisY);
    biaisZ += 0.02 * (gz - biaisZ);
  }
  gx -= biaisX; gy -= biaisY; gz -= biaisZ;

  float pitchAcc = atan2(-ax, sqrt(ay * ay + az * az)) * 180.0 / PI;
  float rollAcc  = atan2(ay, az) * 180.0 / PI;
  if (imuPremiereMesure || dt > 0.2) {
    pitch = pitchAcc;
    roll  = rollAcc;
    imuPremiereMesure = false;
    return;
  }
  // Filtre complémentaire : le gyroscope pour la réactivité, l'accéléromètre pour ne pas dériver
  pitch = 0.96 * (pitch + gy * dt) + 0.04 * pitchAcc;
  roll  = 0.96 * (roll  + gx * dt) + 0.04 * rollAcc;

  // Lacet : pas de boussole, on intègre la vitesse de rotation autour de la VERTICALE réelle
  // (projection sur la gravité : pas de blocage ni d'amplification quand la torche est vrillée, levée ou baissée)
  if (!immobile) {
    float r = roll * PI / 180.0, p = pitch * PI / 180.0;
    yaw += (-gx * sin(p) + (gy * sin(r) + gz * cos(r)) * cos(p)) * dt;
  }
}

// Diagnostic : liste les appareils vus sur le bus I2C (A4/A5), "i2c:aucun" si rien ne répond
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

// Débloque le bus I2C : si la carte a redémarré au milieu d'une lecture (ouverture du port par Godot),
// le gyroscope, resté alimenté, peut garder SDA à 0 et ne plus jamais répondre.
// On envoie des impulsions d'horloge sur SCL jusqu'à ce qu'il relâche SDA, puis un STOP.
// Renvoie false si une ligne reste à 0 (fil débranché, court-circuit ou module non alimenté).
bool debloquerI2C() {
  Wire.end();
  pinMode(SDA, INPUT_PULLUP);
  pinMode(SCL, INPUT_PULLUP);
  delayMicroseconds(10);
  for (byte i = 0; i < 18 && digitalRead(SDA) == LOW; i++) {
    pinMode(SCL, OUTPUT); digitalWrite(SCL, LOW); delayMicroseconds(10);
    pinMode(SCL, INPUT_PULLUP); delayMicroseconds(10);
  }
  // STOP : SDA passe de 0 à 1 pendant que SCL est à 1
  pinMode(SDA, OUTPUT); digitalWrite(SDA, LOW); delayMicroseconds(10);
  pinMode(SDA, INPUT_PULLUP); delayMicroseconds(10);
  bool libre = digitalRead(SDA) == HIGH && digitalRead(SCL) == HIGH;
  Wire.begin();
  Wire.setWireTimeout(3000, true);   // un gyroscope mal branché ne bloque jamais la carte
  return libre;
}

// Cherche le gyroscope et annonce le résultat (appelé au démarrage puis chaque seconde s'il manque)
void chercherImu(bool annoncerEchec) {
  bool busLibre = debloquerI2C();
  if (trouverImu()) {
    echecsLecture = 0;
    imuPremiereMesure = true;
    Serial.print(typeImu == BMI160 ? "imu:BMI160 @0x" : "imu:LSM6DS3 @0x");
    Serial.println(imuAdresse, HEX);
  } else if (annoncerEchec) {
    Serial.println("imu:err");
    if (!busLibre) {
      Serial.print("i2c:ligne a 0, SDA=");
      Serial.print(digitalRead(SDA));
      Serial.print(" SCL=");
      Serial.println(digitalRead(SCL));
    }
    scannerI2C();
  }
}

void initialiserImu() {
  delay(100);
  chercherImu(true);
}

void mettreAJourImu() {
  unsigned long maintenant = millis();
  if (imuAdresse == 0) {
    if (maintenant - derniereRecherche >= 1000) {
      derniereRecherche = maintenant;
      chercherImu(false);
    }
    return;
  }
  if (maintenant - dernierImu < IMU_PERIODE_MS) return;
  float dt = (maintenant - dernierImu) / 1000.0;
  dernierImu = maintenant;
  lireImu(dt);

  if (abs(pitch - pitchEnvoye) >= IMU_SEUIL_ENVOI || abs(roll - rollEnvoye) >= IMU_SEUIL_ENVOI
      || abs(yaw - yawEnvoye) >= IMU_SEUIL_ENVOI) {
    pitchEnvoye = pitch;
    rollEnvoye = roll;
    yawEnvoye = yaw;
    Serial.print("imu:");
    Serial.print(pitch, 1);
    Serial.print(',');
    Serial.print(roll, 1);
    Serial.print(',');
    Serial.println(yaw, 1);
  }
}

// Envoie NOM:1 / NOM:0 quand le bouton change d'état (anti-rebond, sans attendre)
void verifierBouton(int pin, bool &etat, unsigned long &dernierChangement, const char *nom) {
  bool appuye = (digitalRead(pin) == LOW);
  if (appuye != etat && millis() - dernierChangement > ANTI_REBOND_MS) {
    etat = appuye;
    dernierChangement = millis();
    Serial.print(nom);
    Serial.println(appuye ? ":1" : ":0");
  }
}

// LEDs de la lampe : 3 = verte + orange + rouge, 2 = orange + rouge, 1 = rouge, 0 = éteintes
void afficherEnergie(int niveau) {
  digitalWrite(LED_VERTE_LAMPE_PIN, niveau >= 3 ? HIGH : LOW);
  digitalWrite(LED_ORANGE_LAMPE_PIN, niveau >= 2 ? HIGH : LOW);
  digitalWrite(LED_ROUGE_LAMPE_PIN, niveau >= 1 ? HIGH : LOW);
}

void lireCommandes() {
  if (Serial.available() <= 0) return;
  String message = Serial.readStringUntil('\n');
  message.trim();
  if (message == "DISCOVER") {           // Connectée à Godot : la LED de l'aimant s'allume
    Serial.println("GDSERIAL_ACK:arduino_uno");
    appaire = true;
    // Godot reçoit l'état actuel des boutons (utile si un bouton est déjà maintenu)
    boutonAvant = !boutonAvant;  dernierChangementAvant = 0;
    boutonAimant = !boutonAimant; dernierChangementAimant = 0;
  }
  else if (message == "L1") aimantActif = true;
  else if (message == "L0") aimantActif = false;
  else if (message.startsWith("energy:")) afficherEnergie(message.substring(7).toInt());
}

// LED de l'aimant : éteinte = pas connectée, allumée = connectée, clignote = aimant actif
void mettreAJourLedAimant() {
  bool allumee = appaire && (!aimantActif || (millis() / CLIGNOTEMENT_MS) % 2 == 0);
  digitalWrite(LED_AIMANT_PIN, allumee ? HIGH : LOW);
}

void setup() {
  Serial.begin(115200);
  Serial.setTimeout(10);   // ne jamais attendre une ligne incomplète

  //pinMode pour les LEDs
  pinMode(LED_AIMANT_PIN, OUTPUT);
  pinMode(LED_ROUGE_LAMPE_PIN, OUTPUT);
  pinMode(LED_ORANGE_LAMPE_PIN, OUTPUT);
  pinMode(LED_VERTE_LAMPE_PIN, OUTPUT);
  afficherEnergie(0);

  //pinMode les boutons
  pinMode(BTN_AIMANT_AVANCER_PIN, INPUT_PULLUP);
  pinMode(BTN_AIMANT_ACTIVER_PIN, INPUT_PULLUP);

  initialiserImu();  // Gyroscope BMI160 ou LSM6DS3
}

void loop() {
  lireCommandes();
  mettreAJourImu();
  mettreAJourLedAimant();

  // Les boutons ne sont envoyés qu'une fois connectée à Godot
  if (appaire) {
    verifierBouton(BTN_AIMANT_AVANCER_PIN, boutonAvant, dernierChangementAvant, "FWD");
    verifierBouton(BTN_AIMANT_ACTIVER_PIN, boutonAimant, dernierChangementAimant, "MAG");
  }
}
