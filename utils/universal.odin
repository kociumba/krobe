package utils

import "core:strconv"
import "core:strings"
import "core:time"

string_to_duration :: proc(input: string) -> Maybe(time.Duration) {
	duration: time.Duration
	input := strings.trim_space(input)

	switch {
	case strings.has_suffix(input, "ms"):
		amount := strings.trim_suffix(input, "ms")
		mult, ok := strconv.parse_int(amount)
		if !ok {
			return nil
		}
		duration = time.Millisecond * time.Duration(mult)
	case strings.has_suffix(input, "s"):
		amount := strings.trim_suffix(input, "s")
		mult, ok := strconv.parse_int(amount)
		if !ok {
			return nil
		}
		duration = time.Second * time.Duration(mult)
	case strings.has_suffix(input, "m"):
		amount := strings.trim_suffix(input, "m")
		mult, ok := strconv.parse_int(amount)
		if !ok {
			return nil
		}
		duration = time.Minute * time.Duration(mult)
	case strings.has_suffix(input, "h"):
		amount := strings.trim_suffix(input, "h")
		mult, ok := strconv.parse_int(amount)
		if !ok {
			return nil
		}
		duration = time.Hour * time.Duration(mult)
	case:
		return nil
	}

	return duration
}
