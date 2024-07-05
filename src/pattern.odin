package src

import "core:strings"
import "core:text/match"

pattern_load_content_simple :: proc(
	manager: ^Undo_Manager,
	content: string,
	pattern: string,
	indentation: int,
	index_at: ^int,
) -> (
	found_any: bool,
) {
	temp := content

	for line in strings.split_lines_iterator(&temp) {
		m := match.matcher_init(line, pattern)

		_, ok := match.matcher_match(&m)
		if ok && m.captures_length > 1 {
			word := match.matcher_capture(&m, 0)
			task_push_undoable(manager, indentation, word, index_at^)
			index_at^ += 1
			found_any = true
		}
	}

	return
}
