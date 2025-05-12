package utils

import "core:log"
import "core:strconv"
import "core:strings"
import "core:testing"
import "core:time"

string_to_duration :: proc(input: string) -> Maybe(time.Duration) {
	defer free_all(context.allocator)
	input_str := strings.trim_space(input)
	if len(input_str) == 0 {
		return nil
	}

	suffix_map := make(map[string]time.Duration, 4)
	suffix_map["ms"] = time.Millisecond
	suffix_map["s"] = time.Second
	suffix_map["m"] = time.Minute
	suffix_map["h"] = time.Hour

	// iteration order to make sure we catch longest to shortest
	suffixes := [?]string{"ms", "h", "m", "s"}

	for suffix in suffixes {
		if strings.has_suffix(input_str, suffix) {
			amount := strings.trim_suffix(input_str, suffix)
			if len(amount) == 0 {
				return nil
			}
			amount = strings.trim_space(amount)

			mult, ok := strconv.parse_int(amount)
			if !ok {
				// mult_f, ok_f := strconv.parse_f64(amount) // doesn't work couse odin doesn't like casting floats to i64, may be able to get it to work later with precision loss
                // if !ok_f {
                //     return nil
                // }
                // return suffix_map[suffix] * time.Duration(mult_f)
                return nil
			}
			return suffix_map[suffix] * time.Duration(mult)
		}
	}

	return nil
}

@(test)
string_to_duration_test :: proc(t: ^testing.T) {
	testing.expect(t, string_to_duration("10ms") == time.Millisecond * 10)
	testing.expect(t, string_to_duration("20s") == time.Second * 20)
	testing.expect(t, string_to_duration("40m") == time.Minute * 40)
	testing.expect(t, string_to_duration("2h") == time.Hour * 2)

	testing.expect_value(t, string_to_duration(" 10ms "), time.Millisecond * 10)
	testing.expect_value(t, string_to_duration("10 ms"), time.Millisecond * 10)
	
	testing.expect_value(t, string_to_duration(""), nil)
	testing.expect_value(t, string_to_duration("slcancla"), nil)
	testing.expect_value(t, string_to_duration("ms"), nil)
	testing.expect_value(t, string_to_duration(" "), nil)
}
