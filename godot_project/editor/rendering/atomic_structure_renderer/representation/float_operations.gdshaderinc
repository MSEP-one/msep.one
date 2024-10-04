// Holds the logic to operate with floats like if they was booleans

float float_eq(float a, float b) {
	return float(abs(a - b) < 0.001);
}

float float_neq(float x, float y) {
  return step(0.001, abs(x - y));
}

float float_not(float a) {
	return 1.0 - a;
}

float float_or(float a, float b) {
    return 1.0 - (1.0 - a) * (1.0 - b);
}

float float_or_3(float a, float b, float c) {
    return float_or(a, float_or(b, c));
}

float float_and(float a, float b) {
    return a * b;
}

float float_and_3(float a, float b, float c) {
    return a * b * c;
}

vec2 decode_one_float_into_two(float input, int precision) {
    vec2 output = vec2(mod(input, float(precision)), floor(input / float(precision)));
    return output / float(precision - 1);
}