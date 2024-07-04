package src

import "base:intrinsics"
import "core:math/ease"
import "core:math/noise"
import "core:math/rand"
import "cutf8"
import "vendor:fontstash"

// NOTE noise return -1 to 1 range

// options
// lifetime scale 0.5-4
// alpha max 0.1-1
// screenshake amount
// screenshake lifetime (how quick it ends)

P_SPAWN_HIGH :: 10
P_SPAWN_LOW :: 4

PM_State :: struct {
	particles:   [dynamic]PM_Particle,
	spawn_next:  bool,

	// coloring
	color_seed:  i64,
	color_count: f64,

	// caret color
	caret_color: Color,
}
pm_state: PM_State

PM_Particle :: struct {
	lifetime:       f32,
	lifetime_count: f32,
	delay:          f32, // delay until drawn
	x, y:           f32,
	xoff, yoff:     f32, // camera offset at the spawn time
	radius:         f32,
	color:          Color,
	seed:           i64,
}

power_mode_init :: proc() {
	pm_state.particles = make([dynamic]PM_Particle, 0, 256)
	pm_state.color_seed = intrinsics.read_cycle_counter()
}

power_mode_destroy :: proc() {
	delete(pm_state.particles)
}

power_mode_clear :: proc() {
	clear(&pm_state.particles)
	pm_state.color_count = 0
}

power_mode_check_spawn :: proc() {
	if !pm_show() {
		return
	}

	if pm_state.spawn_next {
		power_mode_spawn_at_caret()
		pm_state.spawn_next = false
	}
}

// simple line spawn per glyph
power_mode_spawn_along_text :: proc(text: string, x, y: f32, color: Color) {
	if !pm_show() {
		return
	}

	fcs_ahv(.LEFT, .TOP)
	fcs_size(DEFAULT_FONT_SIZE * TASK_SCALE)
	fcs_font(font_regular)
	iter := fontstash.TextIterInit(&gs.fc, x, y, text)
	q: fontstash.Quad

	cam := mode_panel_cam()
	cam_screenshake_reset(cam)

	for fontstash.TextIterNext(&gs.fc, &iter, &q) {
		power_mode_spawn_at(iter.x, iter.y, cam.offset_x, cam.offset_y, P_SPAWN_LOW, color)
	}
}

// NOTE using rendered glyphs only
power_mode_spawn_along_task_text :: proc(task: ^Task, task_count: int) {
	if !pm_show() {
		return
	}

	if task.box.rendered_glyphs != nil {
		text := ss_string(&task.box.ss)
		color := theme_task_text(task.state)
		cam := mode_panel_cam()
		cam_screenshake_reset(cam)
		ds: cutf8.Decode_State
		count: int

		//TODO: Commented-out "codepoint".
		for _, i in cutf8.ds_iter(&ds, text) {
			glyph := task.box.rendered_glyphs[i]
			delay := f32(count) * 0.002 + f32(task_count) * 0.02
			power_mode_spawn_at(
				glyph.x,
				glyph.y,
				cam.offset_x,
				cam.offset_y,
				P_SPAWN_LOW / 2,
				color,
				delay,
			)
			count += 1
		}
	}
}

// spawn at the global caret
power_mode_spawn_at_caret :: proc() {
	if !pm_show() {
		return
	}

	cam := mode_panel_cam()
	x := f32(app.caret.rect.l)
	y := f32(app.caret.rect.t) + rect_heightf_halfed(app.caret.rect)
	color: Color = pm_particle_colored() ? {} : pm_state.caret_color
	power_mode_spawn_at(x, y, cam.offset_x, cam.offset_y, P_SPAWN_HIGH, color)
}

// spawn particles through random points of a rectangle
power_mode_spawn_rect :: proc(rect: RectI, count: int, color: Color = {}) {
	cam := mode_panel_cam()
	cam_screenshake_reset(cam)

	for i in 0 ..< count {
		x := rand.float32() * rect_widthf(rect) + f32(rect.l)
		y := rand.float32() * rect_heightf(rect) + f32(rect.t)
		delay := f32(i) * 0.001
		power_mode_spawn_at(x, y, cam.offset_x, cam.offset_y, P_SPAWN_LOW, color, delay)
	}
}

// spawn the wanted count of particles with the properties
power_mode_spawn_at :: proc(
	x, y: f32,
	xoff, yoff: f32,
	count: int,
	color := Color{},
	delay: f32 = 0,
) {
	width := 20 * TASK_SCALE
	height := DEFAULT_FONT_SIZE * TASK_SCALE * 2
	size := 3 * TASK_SCALE

	// NOTE could resize upfront?
	lifetime_opt := pm_particle_lifetime()

	for _ in 0 ..< count {
		life := rand.float32() * lifetime_opt + 0.5 // min is 0.5

		// custom delay
		d := delay
		if d == 0 {
			d = rand.float32() * 0.25
		}

		// custom color
		c := color
		if c == {} {
			// normalize to 0 -> 1
			value :=
				(noise.noise_2d(pm_state.color_seed, {pm_state.color_count * 0.01, 0}) + 1) / 2
			c = color_hsv_to_rgb(value, 1, 1)
		}

		append(
			&pm_state.particles,
			PM_Particle {
				lifetime       = life,
				lifetime_count = life,
				delay          = d,
				x              = x + rand.float32() * width - width / 2,
				y              = y + rand.float32() * height - height / 2,
				radius         = 2 + rand.float32() * size,
				color          = c,
				xoff           = -xoff,
				yoff           = -yoff,

				// random seed
				seed           = intrinsics.read_cycle_counter(),
			},
		)

		pm_state.color_count += 1
	}
}

power_mode_update :: proc() {
	if !pm_show() {
		return
	}

	for i := len(pm_state.particles) - 1; i >= 0; i -= 1 {
		p := &pm_state.particles[i]

		if p.delay > 0 {
			p.delay -= gs.dt
			continue
		}

		if p.lifetime_count > 0 {
			p.lifetime_count -= gs.dt
			x_dir := noise.noise_2d(p.seed, {f64(p.lifetime_count) / 2, 0})
			y_dir := noise.noise_2d(p.seed, {f64(p.lifetime_count) / 2, 1})
			p.x += x_dir * TASK_SCALE * TASK_SCALE
			p.y += y_dir * TASK_SCALE * TASK_SCALE
		} else {
			unordered_remove(&pm_state.particles, i)
		}
	}
}

power_mode_render :: proc(target: ^Render_Target) {
	if !pm_show() {
		return
	}

	cam := mode_panel_cam()
	xoff, yoff: f32
	alpha_opt := pm_particle_alpha_scale()

	for i := len(pm_state.particles) - 1; i >= 0; i -= 1 {
		p := &pm_state.particles[i]

		if p.delay > 0 {
			continue
		}

		alpha := clamp((p.lifetime_count / p.lifetime) * alpha_opt, 0, 1)

		// when alpha has reached 0 we can shortcut here
		if alpha == 0 {
			unordered_remove(&pm_state.particles, i)
			continue
		}

		xoff = p.xoff + cam.offset_x
		yoff = p.yoff + cam.offset_y
		color := color_alpha(p.color, alpha)
		radius := max(1, p.radius * ease.cubic_out(alpha))
		render_circle(target, p.x + xoff, p.y + yoff, radius, color, true)
	}
}

power_mode_running :: #force_inline proc() -> bool {
	return len(pm_state.particles) != 0
}

power_mode_issue_spawn :: #force_inline proc() {
	if !pm_show() {
		return
	}

	pm_state.spawn_next = true

	cam := mode_panel_cam()
	cam_screenshake_reset(cam)
}

cam_screenshake_reset :: #force_inline proc(cam: ^Pan_Camera) {
	cam.screenshake_counter = 0
}

power_mode_set_caret_color :: proc() {
	if app.task_head != -1 {
		task := app_task_head()
		// TODO make this syntax based instead
		pm_state.caret_color = theme_task_text(task.state)
	}
}
