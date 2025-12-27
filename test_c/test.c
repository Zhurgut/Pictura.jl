#include "../zig-out/lib/picturalib.h"
#include <stdlib.h>

float myabs(float x) {
    return x < 0 ? -x : x;
}

void draw_points(Image image, float x, float y, float px, float py) {
    float stroke_radius = myabs(x - px) + myabs(y - py);
    draw_point(image, x, y, 22.0 / 255, 42.0 / 255, 219.0 / 255, 1.0, stroke_radius);
    draw_point(image, x, y, 18.0 / 255, 167.0 / 255, 222.0 / 255, 1.0, 0.6*stroke_radius);
    draw_point(image, x, y, 1.0, 1.0, 1.0, 1.0, 0.3*stroke_radius);
}

int main() {
    init(800, 600, 0);

    int running = 1;
    int width, height;
    float mousex, mousey;
    float pmousex, pmousey;
    Image canvas;

    canvas = get_canvas();
    draw_background(canvas, 1.0, 1.0, 1.0, 1.0);

    int frame = 0;

    while (running) {
        wait_until_next_frame();
        handle_events();

        canvas = get_canvas();
        get_window_size(&width, &height);
        get_mouse_state(&mousex, &mousey, &pmousex, &pmousey, NULL, NULL, NULL);

        draw_background(canvas, 1.0, 1.0, 1.0, 0.02);

        draw_points(canvas, mousex, mousey, pmousex, pmousey);

        present();

        frame++;

        if (frame == 1000) {
            quit();
            break;
        }
    }

    


}

