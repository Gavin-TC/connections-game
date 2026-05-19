shader_type canvas_item;

// Allows you to change the thickness of the black line in the Inspector
uniform float line_thickness : hint_range(1.0, 5.0) = 1.0;

void fragment() {
    // Read the flattened CanvasGroup texture
    vec4 col = texture(TEXTURE, UV);

    // Only apply the effect to pixels that are actually solid (part of the stone)
    if (col.a > 0.1) {
        // Calculate the size of a single pixel based on thickness
        vec2 ps = TEXTURE_PIXEL_SIZE * line_thickness;
        
        // Look at the 4 neighboring pixels (Up, Down, Left, Right)
        float up = texture(TEXTURE, UV + vec2(0.0, -ps.y)).a;
        float down = texture(TEXTURE, UV + vec2(0.0, ps.y)).a;
        float left = texture(TEXTURE, UV + vec2(-ps.x, 0.0)).a;
        float right = texture(TEXTURE, UV + vec2(ps.x, 0.0)).a;

        // If ANY of those 4 neighboring pixels are transparent (air)...
        if (up < 0.1 || down < 0.1 || left < 0.1 || right < 0.1) {
            // ...turn this pixel pure black.
            COLOR = vec4(0.0, 0.0, 0.0, col.a);
        } else {
            // Otherwise, just draw the normal stone pixel
            COLOR = col;
        }
    } else {
        // Keep transparent pixels completely transparent
        COLOR = col;
    }
}