#include "params.h"
#include <math.h>

// PWM config (L298N works well at ~1kHz, but ESP32 can go higher)
const int PWM_FREQ = 1000;
const int PWM_RES = 8;  // 0-255
const int PWM_MAX = (1 << PWM_RES) - 1;

const float DEADZONE = 0.05f;

static float clamp(float v, float minV, float maxV) {
	if (v > maxV) return maxV;
	if (v < minV) return minV;
	return v;
}

static float applyDeadzone(float v) {
	if (fabs(v) < DEADZONE) return 0.0f;
	return v;
}

// Set L298N motor: in1/in2 for direction, pwmPin for speed
static void setL298Motor(int in1, int in2, int pwmPin, float speed) {
	speed = clamp(speed, -1.0f, 1.0f);

	if (speed > 0.0f) {
		// Forward
		digitalWrite(in1, HIGH);
		digitalWrite(in2, LOW);
	} else if (speed < 0.0f) {
		// Reverse
		digitalWrite(in1, LOW);
		digitalWrite(in2, HIGH);
	} else {
		// Brake (both LOW = coast, both HIGH = brake)
		digitalWrite(in1, LOW);
		digitalWrite(in2, LOW);
	}

	int duty = (int)(fabs(speed) * PWM_MAX);
	ledcWrite(pwmPin, duty);  // ESP32-S3: use pin directly
}

void controlSetup() {
	// Front driver direction pins
	pinMode(FRONT_IN1, OUTPUT);
	pinMode(FRONT_IN2, OUTPUT);
	pinMode(FRONT_IN3, OUTPUT);
	pinMode(FRONT_IN4, OUTPUT);

	// Rear driver direction pins
	pinMode(REAR_IN1, OUTPUT);
	pinMode(REAR_IN2, OUTPUT);
	pinMode(REAR_IN3, OUTPUT);
	pinMode(REAR_IN4, OUTPUT);

  ledcSetup(CH_FRONT_LEFT, PWM_FREQ, PWM_RES);
  ledcSetup(CH_FRONT_RIGHT, PWM_FREQ, PWM_RES);
  ledcSetup(CH_REAR_LEFT, PWM_FREQ, PWM_RES);
  ledcSetup(CH_REAR_RIGHT, PWM_FREQ, PWM_RES);

	ledcAttachPin(FRONT_ENA, CH_FRONT_LEFT);  // Front-left PWM
	ledcAttachPin(FRONT_ENB, CH_FRONT_RIGHT);  // Front-right PWM
	ledcAttachPin(REAR_ENA, CH_REAR_LEFT);   // Rear-left PWM
	ledcAttachPin(REAR_ENB, CH_REAR_RIGHT);   // Rear-right PWM

	// Stop all motors initially
	setL298Motor(FRONT_IN1, FRONT_IN2, FRONT_ENA, 0);  // Front-left
	setL298Motor(FRONT_IN3, FRONT_IN4, FRONT_ENB, 0);  // Front-right
	setL298Motor(REAR_IN1, REAR_IN2, REAR_ENA, 0);     // Rear-left
	setL298Motor(REAR_IN3, REAR_IN4, REAR_ENB, 0);     // Rear-right
}

// Tank-style differential steering:
// tx = steering (left joystick X), sy = throttle (right joystick Y)
void controlUpdate() {
	float steering = applyDeadzone(tx);
	float throttle = applyDeadzone(sy);

	// Differential drive mixing
	float left = clamp(throttle + steering, -1.0f, 1.0f);
	float right = clamp(throttle - steering, -1.0f, 1.0f);

	// Front driver: front-left (Motor A) + front-right (Motor B)
	setL298Motor(FRONT_IN1, FRONT_IN2, FRONT_ENA, left);
	setL298Motor(FRONT_IN3, FRONT_IN4, FRONT_ENB, right);

	// Rear driver: rear-left (Motor A) + rear-right (Motor B)
	setL298Motor(REAR_IN1, REAR_IN2, REAR_ENA, left);
	setL298Motor(REAR_IN3, REAR_IN4, REAR_ENB, right);
}
