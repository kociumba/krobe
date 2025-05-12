#+feature dynamic-literals
package utils

import "core:strconv"
import "core:strings"
import "core:testing"
import "core:time"

string_to_duration :: proc(input: string) -> Maybe(time.Duration) {
	defer free_all(context.allocator)
    input_str := strings.trim_space(input)

    // dynamic litteral allocates using context.allocator
	suffix_map := map[string]time.Duration {
		"ms" = time.Millisecond,
		"s"  = time.Second,
		"m"  = time.Minute,
		"h"  = time.Hour,
	}

	for suffix, unit in suffix_map {
		if strings.has_suffix(input_str, suffix) {
			amount := strings.trim_suffix(input_str, suffix)
			mult, ok := strconv.parse_int(amount)
			if !ok {
				return nil
			}
			return unit * time.Duration(mult)
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

	testing.expect(t, string_to_duration("slcancla") == nil)
}
