// simple package to iterate utf8 codepoints quickly
package cutf8

import "core:slice"
import "core:strings"
import "core:unicode"

@(private)
UTF8_ACCEPT :: 0

@(private)
UTF8_REJECT :: 1

@(private)
utf8d := [400]u8 {
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0, // 00..1f
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0, // 20..3f
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0, // 40..5f
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0, // 60..7f
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	9,
	9,
	9,
	9,
	9,
	9,
	9,
	9,
	9,
	9,
	9,
	9,
	9,
	9,
	9,
	9, // 80..9f
	7,
	7,
	7,
	7,
	7,
	7,
	7,
	7,
	7,
	7,
	7,
	7,
	7,
	7,
	7,
	7,
	7,
	7,
	7,
	7,
	7,
	7,
	7,
	7,
	7,
	7,
	7,
	7,
	7,
	7,
	7,
	7, // a0..bf
	8,
	8,
	2,
	2,
	2,
	2,
	2,
	2,
	2,
	2,
	2,
	2,
	2,
	2,
	2,
	2,
	2,
	2,
	2,
	2,
	2,
	2,
	2,
	2,
	2,
	2,
	2,
	2,
	2,
	2,
	2,
	2, // c0..df
	0xa,
	0x3,
	0x3,
	0x3,
	0x3,
	0x3,
	0x3,
	0x3,
	0x3,
	0x3,
	0x3,
	0x3,
	0x3,
	0x4,
	0x3,
	0x3, // e0..ef
	0xb,
	0x6,
	0x6,
	0x6,
	0x5,
	0x8,
	0x8,
	0x8,
	0x8,
	0x8,
	0x8,
	0x8,
	0x8,
	0x8,
	0x8,
	0x8, // f0..ff
	0x0,
	0x1,
	0x2,
	0x3,
	0x5,
	0x8,
	0x7,
	0x1,
	0x1,
	0x1,
	0x4,
	0x6,
	0x1,
	0x1,
	0x1,
	0x1, // s0..s0
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	0,
	1,
	1,
	1,
	1,
	1,
	0,
	1,
	0,
	1,
	1,
	1,
	1,
	1,
	1, // s1..s2
	1,
	2,
	1,
	1,
	1,
	1,
	1,
	2,
	1,
	2,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	2,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1, // s3..s4
	1,
	2,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	2,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	3,
	1,
	3,
	1,
	1,
	1,
	1,
	1,
	1, // s5..s6
	1,
	3,
	1,
	1,
	1,
	1,
	1,
	3,
	1,
	3,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	3,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	1, // s7..s8
}

// decode codepoints from a state
decode :: #force_inline proc(state: ^rune, codep: ^rune, b: byte) -> bool {
	b := rune(b)
	type := utf8d[b]
	codep^ = (state^ != UTF8_ACCEPT) ? ((b & 0x3f) | (codep^ << 6)) : ((0xff >> type) & (b))
	state^ = rune(utf8d[256 + state^ * 16 + rune(type)])
	return state^ == UTF8_ACCEPT
}

// get codepoint count back
count :: proc(text: string) -> (count: int) {
	codepoint, state: rune

	for i in 0 ..< len(text) {
		if decode(&state, &codepoint, text[i]) {
			count += 1
		}
	}

	return state == UTF8_ACCEPT ? count : -1
}

// Global state to iterate instead of spawning it everywhere
Decode_State :: struct {
	state:              rune,
	byte_offset:        int,
	byte_offset_old:    int,
	codepoint_count:    int,
	codepoint_previous: rune,
}

// decode until the word ended using state
ds_iter :: proc(
	ds: ^Decode_State,
	text: string,
) -> (
	codepoint: rune,
	codepoint_index: int,
	ok: bool,
) {
	ds.byte_offset_old = ds.byte_offset

	// advance till the next codepoint is done
	for ds.byte_offset < len(text) {
		ds.byte_offset += 1

		if decode(&ds.state, &codepoint, text[ds.byte_offset - 1]) {
			codepoint_index = ds.codepoint_count
			ds.codepoint_count += 1
			ok = true
			return
		}
	}

	return
}

ds_recount :: proc(ds: ^Decode_State, text: string) -> int {
	ds^ = {}
	codepoint: rune

	for ds.byte_offset < len(text) {
		if decode(&ds.state, &codepoint, text[ds.byte_offset]) {
			ds.codepoint_count += 1
		}

		ds.byte_offset += 1
	}

	return ds.codepoint_count
}

ds_string_till_codepoint_index :: proc(
	ds: ^Decode_State,
	text: string,
	codepoint_index: int,
) -> (
	res: string,
) {
	ds^ = {}
	codepoint: rune

	for ds.byte_offset < len(text) {
		ds.byte_offset += 1

		if decode(&ds.state, &codepoint, text[ds.byte_offset - 1]) {
			if codepoint_index == ds.codepoint_count {
				res = text[:ds.byte_offset - 1]
				return
			}

			ds.codepoint_count += 1
		}
	}

	return text[:]
}

ds_byte_offset_till_codepoint_index :: proc(
	ds: ^Decode_State,
	text: string,
	codepoint_index: int,
) -> (
	res: int,
) {
	ds^ = {}
	codepoint: rune

	for ds.byte_offset < len(text) {
		if decode(&ds.state, &codepoint, text[ds.byte_offset]) {
			if codepoint_index == ds.codepoint_count {
				res = ds.byte_offset
				return
			}

			ds.codepoint_count += 1
		}

		ds.byte_offset += 1
	}

	return ds.byte_offset
}

// decode until the word ended using state
ds_string_selection :: proc(
	ds: ^Decode_State,
	text: string,
	low, high: int,
) -> (
	res: string,
	ok: bool,
) {
	codepoint: rune
	start := -1
	end := -1

	for ds.byte_offset < len(text) {
		if decode(&ds.state, &codepoint, text[ds.byte_offset]) {
			if low == ds.codepoint_count {
				start = ds.byte_offset
			}

			if high == ds.codepoint_count {
				end = ds.byte_offset
			}

			// codepoint_index = codepoint_count
			ds.codepoint_count += 1
		}

		ds.byte_offset += 1
	}

	if end == -1 && ds.codepoint_count == high {
		end = ds.codepoint_count
	}

	if start != -1 && end != -1 {
		res = text[start:end]
		ok = true
	}

	return
}

byte_indices_to_character_indices :: proc(
	text: string,
	byte_start: int,
	byte_end: int,
	head: ^int,
	tail: ^int,
) #no_bounds_check {
	codepoint: rune
	state: rune
	codepoint_offset: int
	byte_offset: int

	for byte_offset < len(text) {
		if decode(&state, &codepoint, text[byte_offset]) {
			if byte_offset == byte_start {
				tail^ = codepoint_offset
			}

			if byte_offset == byte_end {
				head^ = codepoint_offset
			}

			codepoint_offset += 1
		}

		byte_offset += 1
	}

	if byte_offset == byte_start {
		tail^ = codepoint_offset
	}

	if byte_offset == byte_end {
		head^ = codepoint_offset
	}
}

to_lower :: proc(builder: ^strings.Builder, text: string) -> string {
	state, codepoint: rune

	for byte_offset in 0 ..< len(text) {
		if decode(&state, &codepoint, text[byte_offset]) {
			strings.write_rune(builder, unicode.to_lower(codepoint))
		}
	}

	return strings.to_string(builder^)
}

to_runes :: proc(text: string, allocator := context.allocator) -> []rune {
	temp := make([dynamic]rune, 0, 256, context.temp_allocator)
	state, codepoint: rune

	for byte_offset in 0 ..< len(text) {
		if decode(&state, &codepoint, text[byte_offset]) {
			append(&temp, codepoint)
		}
	}

	return slice.clone(temp[:], allocator)
}
