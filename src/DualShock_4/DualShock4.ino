#include <Bluepad32.h>

// Pins de salida hacia los puertos periféricos JA (JA1, JA2, JA3, JA4, JA7, JA8)
const int PIN_UP    = 26; // JA1 (Up)
const int PIN_DOWN  = 25; // JA2 (Down)
const int PIN_LEFT  = 33; // JA3 (Left)
const int PIN_RIGHT = 32; // JA4 (Right)
const int PIN_L1    = 27; // JA7 (Reset)
const int PIN_R1    = 14; // JA8 (Start)

// Máscara de bits para el D-pad usando Bluepad32
const uint8_t MASK_UP    = 0x01;
const uint8_t MASK_DOWN  = 0x02;
const uint8_t MASK_RIGHT = 0x04;
const uint8_t MASK_LEFT  = 0x08;

ControllerPtr myController = nullptr;

void onConnectedController(ControllerPtr ctl) {
  if (myController == nullptr) {
    Serial.println("DualShock 4 connected!");
    myController = ctl;
    ctl->setColorLED(0, 255, 0); // Verde = Control conectado
  }
}

void onDisconnectedController(ControllerPtr ctl) {
  if (myController == ctl) {
    Serial.println("DualShock 4 disconnected.");
    myController = nullptr;
    digitalWrite(PIN_UP, LOW);
    digitalWrite(PIN_DOWN, LOW);
    digitalWrite(PIN_LEFT, LOW);
    digitalWrite(PIN_RIGHT, LOW);
    digitalWrite(PIN_L1, HIGH);
    digitalWrite(PIN_R1, LOW);
  }
}

void setup() {
  Serial.begin(115200);

  int pins[] = {PIN_UP, PIN_DOWN, PIN_LEFT, PIN_RIGHT, PIN_L1, PIN_R1};
  for (int i = 0; i < 6; i++) {
    pinMode(pins[i], OUTPUT);
    digitalWrite(pins[i], LOW);
  }
  digitalWrite(PIN_L1, HIGH);
  BP32.setup(&onConnectedController, &onDisconnectedController);
  Serial.println("Waiting for DualShock 4...");
}

void loop() {
  BP32.update();

  if (myController && myController->isConnected()) {
    uint8_t dpad = myController->dpad();

    bool up    = (dpad & MASK_UP)    != 0;
    bool down  = (dpad & MASK_DOWN)  != 0;
    bool left  = (dpad & MASK_LEFT)  != 0;
    bool right = (dpad & MASK_RIGHT) != 0;
    bool l1    = myController->l1();
    bool r1    = myController->r1();

    digitalWrite(PIN_UP,    up    ? HIGH : LOW);
    digitalWrite(PIN_DOWN,  down  ? HIGH : LOW);
    digitalWrite(PIN_LEFT,  left  ? HIGH : LOW);
    digitalWrite(PIN_RIGHT, right ? HIGH : LOW);
    digitalWrite(PIN_L1,    l1    ? LOW  : HIGH);
    digitalWrite(PIN_R1,    r1    ? HIGH : LOW);

    if (up || down || left || right || l1 || r1) {
      Serial.printf("UP:%d DOWN:%d LEFT:%d RIGHT:%d L1:%d R1:%d\n", up, down, left, right, l1, r1);
    }
  }
  delay(10);
}
