#include "params.h"
#include <math.h>

// PWM config
const int PWM_FREQ = 1000;
const int PWM_RES = 8;  // 0-255
const int PWM_MAX = (1 << PWM_RES) - 1;

const float MOTOR_SLEW_RATE_PER_SEC = 10.0f;
const float STRAFE_INPUT_SIGN = -1.0f;
const float THROTTLE_INPUT_SIGN = -1.0f;

// Minimum effective power where the car reliably moves.
const float MIN_EFFECTIVE_POWER = 0.45f;

// Use the same startup threshold on all wheels so standstill -> movement
// happens at the same instant.
const float START_CMD_ALL = 0.20f;

const int MIN_DUTY_ALL = 80;

// Motor polarity calibration.
const float DIR_FRONT_LEFT = 1.0f;
const float DIR_FRONT_RIGHT = 1.0f;
const float DIR_REAR_LEFT = 1.0f;
const float DIR_REAR_RIGHT = 1.0f;

static float cmdFrontLeft = 0.0f;
static float cmdFrontRight = 0.0f;
static float cmdRearLeft = 0.0f;
static float cmdRearRight = 0.0f;
static unsigned long lastControlMs = 0;

static void setL298Motor(
	int in1,
	int in2,
	int pwmPin,
	float speed,
	float startCmd,
	int minDuty
);

static float slewToward(float current, float target, float maxDelta);

static float clamp(float v, float minV, float maxV) {
	if (v > maxV) return maxV;
	if (v < minV) return minV;
	return v;
}


static float movementPower(float value) {
	float mag = clamp(fabs(value), 0.0f, 1.0f);
	if (mag == 0.0f) return 0.0f;
	return MIN_EFFECTIVE_POWER + (1.0f - MIN_EFFECTIVE_POWER) * mag;
}

static float applyStartBoost(float v, float startCmd) {
	float mag = fabs(v);
	if (mag > 0.0f && mag < startCmd) {
		return copysign(startCmd, v);
	}
	return v;
}


static WheelTargets scaledTargets(
	float baseFrontLeft,
	float baseFrontRight,
	float baseRearLeft,
	float baseRearRight,
	float power
) {
	float scale = movementPower(power);
	WheelTargets targets;
	targets.frontLeft = baseFrontLeft * scale;
	targets.frontRight = baseFrontRight * scale;
	targets.rearLeft = baseRearLeft * scale;
	targets.rearRight = baseRearRight * scale;
	return targets;
}

static WheelTargets applyWheelPolarity(WheelTargets targets) {
	targets.frontLeft *= DIR_FRONT_LEFT;
	targets.frontRight *= DIR_FRONT_RIGHT;
	targets.rearLeft *= DIR_REAR_LEFT;
	targets.rearRight *= DIR_REAR_RIGHT;
	return targets;
}

static WheelTargets applyStartBoost(WheelTargets targets) {
	targets.frontLeft = applyStartBoost(targets.frontLeft, START_CMD_ALL);
	targets.frontRight = applyStartBoost(targets.frontRight, START_CMD_ALL);
	targets.rearLeft = applyStartBoost(targets.rearLeft, START_CMD_ALL);
	targets.rearRight = applyStartBoost(targets.rearRight, START_CMD_ALL);
	return targets;
}

static DirectionVector readInputVector() {
	DirectionVector vector;
	vector.strafe = tx * STRAFE_INPUT_SIGN;
	vector.forward = sy * THROTTLE_INPUT_SIGN;
	vector.rotate = sx;
	return vector;
}

static WheelTargets resolveDirectionToTargets(const DirectionVector& vector) {
	const float absStrafe = fabs(vector.strafe);
	const float absForward = fabs(vector.forward);
	const float absRotate = fabs(vector.rotate);

	if (absRotate >= absStrafe && absRotate >= absForward && absRotate > 0.0f) {
		return (vector.rotate > 0.0f)
			? scaledTargets(1.0f, -1.0f, 1.0f, -1.0f, absRotate)
			: scaledTargets(-1.0f, 1.0f, -1.0f, 1.0f, absRotate);
	}

	if (absStrafe == 0.0f && absForward == 0.0f) {
		return scaledTargets(0.0f, 0.0f, 0.0f, 0.0f, 0.0f);
	}

	if (absForward > 0.0f && absStrafe == 0.0f) {
		return (vector.forward > 0.0f)
			? scaledTargets(1.0f, 1.0f, 1.0f, 1.0f, absForward)
			: scaledTargets(-1.0f, -1.0f, -1.0f, -1.0f, absForward);
	}

	if (absStrafe > 0.0f && absForward == 0.0f) {
		return (vector.strafe > 0.0f)
			? scaledTargets(1.0f, -1.0f, -1.0f, 1.0f, absStrafe)
			: scaledTargets(-1.0f, 1.0f, 1.0f, -1.0f, absStrafe);
	}

	const float diagonalPower = fmax(absStrafe, absForward);
	if (vector.forward > 0.0f && vector.strafe < 0.0f) {
		return scaledTargets(0.0f, 1.0f, 1.0f, 0.0f, diagonalPower);
	}
	if (vector.forward > 0.0f && vector.strafe > 0.0f) {
		return scaledTargets(1.0f, 0.0f, 0.0f, 1.0f, diagonalPower);
	}
	if (vector.forward < 0.0f && vector.strafe < 0.0f) {
		return scaledTargets(-1.0f, 0.0f, 0.0f, -1.0f, diagonalPower);
	}
	if (vector.forward < 0.0f && vector.strafe > 0.0f) {
		return scaledTargets(0.0f, -1.0f, -1.0f, 0.0f, diagonalPower);
	}

	return scaledTargets(0.0f, 0.0f, 0.0f, 0.0f, 0.0f);
}

static float computeMaxSlewDelta(unsigned long nowMs) {
	float dt = (float)(nowMs - lastControlMs) / 1000.0f;
	lastControlMs = nowMs;
	if (dt < 0.0f) dt = 0.0f;
	if (dt > 0.10f) dt = 0.10f;
	return MOTOR_SLEW_RATE_PER_SEC * dt;
}

static void applySlewToCurrentCommand(const WheelTargets& targets, float maxDelta) {
	cmdFrontLeft = slewToward(cmdFrontLeft, targets.frontLeft, maxDelta);
	cmdFrontRight = slewToward(cmdFrontRight, targets.frontRight, maxDelta);
	cmdRearLeft = slewToward(cmdRearLeft, targets.rearLeft, maxDelta);
	cmdRearRight = slewToward(cmdRearRight, targets.rearRight, maxDelta);
}

static void writeMotorOutputs() {
	setL298Motor(FRONT_IN1, FRONT_IN2, FRONT_ENA, cmdFrontLeft, START_CMD_ALL, MIN_DUTY_ALL);
	setL298Motor(FRONT_IN3, FRONT_IN4, FRONT_ENB, cmdFrontRight, START_CMD_ALL, MIN_DUTY_ALL);
	setL298Motor(REAR_IN1, REAR_IN2, REAR_ENA, cmdRearLeft, START_CMD_ALL, MIN_DUTY_ALL);
	setL298Motor(REAR_IN3, REAR_IN4, REAR_ENB, cmdRearRight, START_CMD_ALL, MIN_DUTY_ALL);
}

static float slewToward(float current, float target, float maxDelta) {
	float delta = target - current;
	if (delta > maxDelta) return current + maxDelta;
	if (delta < -maxDelta) return current - maxDelta;
	return target;
}

// Set L298N motor: in1/in2 for direction, pwmPin for speed.
static void setL298Motor(
	int in1,
	int in2,
	int pwmPin,
	float speed,
	float startCmd,
	int minDuty
) {
	speed = clamp(speed, -1.0f, 1.0f);
	float mag = fabs(speed);

	if (mag < startCmd || speed == 0.0f) {
		digitalWrite(in1, LOW);
		digitalWrite(in2, LOW);
		ledcWrite(pwmPin, 0);
		return;
	}

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

	float scaled = (mag - startCmd) / (1.0f - startCmd);
	scaled = clamp(scaled, 0.0f, 1.0f);
	int duty = minDuty + (int)(scaled * (float)(PWM_MAX - minDuty));
	ledcWrite(pwmPin, duty);
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

  	ledcAttach(FRONT_ENA, PWM_FREQ, PWM_RES);
  	ledcAttach(FRONT_ENB, PWM_FREQ, PWM_RES);
  	ledcAttach(REAR_ENA, PWM_FREQ, PWM_RES);
  	ledcAttach(REAR_ENB, PWM_FREQ, PWM_RES);

	// Stop all motors initially
	setL298Motor(FRONT_IN1, FRONT_IN2, FRONT_ENA, 0, START_CMD_ALL, MIN_DUTY_ALL);   // Front-left
	setL298Motor(FRONT_IN3, FRONT_IN4, FRONT_ENB, 0, START_CMD_ALL, MIN_DUTY_ALL);   // Front-right
	setL298Motor(REAR_IN1, REAR_IN2, REAR_ENA, 0, START_CMD_ALL, MIN_DUTY_ALL);      // Rear-left
	setL298Motor(REAR_IN3, REAR_IN4, REAR_ENB, 0, START_CMD_ALL, MIN_DUTY_ALL);      // Rear-right

	cmdFrontLeft = 0.0f;
	cmdFrontRight = 0.0f;
	cmdRearLeft = 0.0f;
	cmdRearRight = 0.0f;
	lastControlMs = millis();
}

// Omnidirectional (mecanum/X-drive style) control:
// tx = strafe, sy = forward/backward, sx = rotation
void controlUpdate() {
	const DirectionVector direction = readInputVector();
	WheelTargets targets = resolveDirectionToTargets(direction);
	targets = applyWheelPolarity(targets);
	targets = applyStartBoost(targets);

	const float maxDelta = computeMaxSlewDelta(millis());
	applySlewToCurrentCommand(targets, maxDelta);
	writeMotorOutputs();
}
