#include "params.h"
#include <math.h>

static unsigned long lastMotorTraceMs = 0;

static void setL298Motor(
	int in1,
	int in2,
	int pwmPin,
	float speed,
	float startCmd,
	int minDuty
);

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

static void writeMotorOutputs(const WheelTargets& targets) {
	setL298Motor(FRONT_IN1, FRONT_IN2, FRONT_ENA, targets.frontLeft,  START_CMD_ALL, MIN_DUTY_ALL);
	setL298Motor(FRONT_IN3, FRONT_IN4, FRONT_ENB, targets.frontRight, START_CMD_ALL, MIN_DUTY_ALL);
	setL298Motor(REAR_IN1,  REAR_IN2,  REAR_ENA,  targets.rearLeft,   START_CMD_ALL, MIN_DUTY_ALL);
	setL298Motor(REAR_IN3,  REAR_IN4,  REAR_ENB,  targets.rearRight,  START_CMD_ALL, MIN_DUTY_ALL);
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
		digitalWrite(in1, HIGH);
		digitalWrite(in2, LOW);
	} else {
		digitalWrite(in1, LOW);
		digitalWrite(in2, HIGH);
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
	setL298Motor(FRONT_IN1, FRONT_IN2, FRONT_ENA, 0, START_CMD_ALL, MIN_DUTY_ALL);
	setL298Motor(FRONT_IN3, FRONT_IN4, FRONT_ENB, 0, START_CMD_ALL, MIN_DUTY_ALL);
	setL298Motor(REAR_IN1,  REAR_IN2,  REAR_ENA,  0, START_CMD_ALL, MIN_DUTY_ALL);
	setL298Motor(REAR_IN3,  REAR_IN4,  REAR_ENB,  0, START_CMD_ALL, MIN_DUTY_ALL);
}

static WheelTargets applyDriveScale(WheelTargets targets) {
	targets.frontLeft  *= driveScale;
	targets.frontRight *= driveScale;
	targets.rearLeft   *= driveScale;
	targets.rearRight  *= driveScale;
	return targets;
}

void controlUpdate() {
	const DirectionVector direction = readInputVector();
	WheelTargets targets = resolveDirectionToTargets(direction);
	targets = applyWheelPolarity(targets);
	targets = applyDriveScale(targets);
	writeMotorOutputs(targets);

	if (LOG_CONTROL_PACKETS && millis() - lastMotorTraceMs >= 300) {
		logTrace(
			"INFO",
			"MOTOR",
			"intent tx=%.2f ty=%.2f sx=%.2f sy=%.2f FL=%.2f FR=%.2f RL=%.2f RR=%.2f",
			tx,
			ty,
			sx,
			sy,
			targets.frontLeft,
			targets.frontRight,
			targets.rearLeft,
			targets.rearRight
		);
		lastMotorTraceMs = millis();
	}
}
