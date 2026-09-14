#include "raylib.h"
#include "raymath.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

#ifndef APP_VERSION
#define APP_VERSION "0.1.0"
#endif

#define WINDOW_WIDTH  800
#define WINDOW_HEIGHT 600

// Iris color definitions
static const Color IRIS_OUTER = (Color){ 20, 75, 145, 255 };  // Deep sapphire blue
static const Color IRIS_MID   = (Color){ 52, 152, 219, 255 };  // Vibrant azure
static const Color IRIS_INNER = (Color){ 120, 205, 250, 255 }; // Light cyan highlight

// Draw stylized eyelashes along the upper lid
static void DrawUpperEyelashes(Vector2 center, float radiusX, float radiusY, float scale) {
    const int lashCount = 14;
    Color lashColor = (Color){ 25, 25, 32, 220 };
    for (int i = 0; i < lashCount; i++) {
        float t = (float)i / (float)(lashCount - 1); // 0 to 1 across the eye
        // Angle along top half of ellipse (from PI to 0)
        float angle = PI - t * PI;
        // Base point on eyelid margin
        float bx = center.x + radiusX * cosf(angle);
        float by = center.y - radiusY * sinf(angle);

        // Lash direction radiates outward from center, curving upward
        float lashAngle = angle + 0.15f * (t - 0.5f);
        float lashLength = (14.0f + 16.0f * sinf(t * PI)) * scale;

        float tipX = bx + lashLength * cosf(lashAngle) * 0.7f;
        float tipY = by - fabsf(lashLength * sinf(lashAngle)) * 1.1f;

        DrawLineEx((Vector2){ bx, by }, (Vector2){ tipX, tipY }, 2.0f * scale, lashColor);
    }
}



int main(int argc, char *argv[]) {
    // Determine invocation name
    const char *progName = "ocio";
    if (argc > 0 && argv[0] != NULL) {
        const char *slash = strrchr(argv[0], '/');
        progName = slash ? slash + 1 : argv[0];
    }

    // Handle command-line options
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--version") == 0 || strcmp(argv[i], "-v") == 0) {
            printf("%s %s\n", progName, APP_VERSION);
            return 0;
        }
        if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
            printf("Usage: %s [OPTIONS]\n\n", progName);
            printf("Options:\n");
            printf("  -v, --version    Print version and exit\n");
            printf("  -h, --help       Print this help message and exit\n");
            return 0;
        }
    }

    // Configure window
    SetConfigFlags(FLAG_WINDOW_RESIZABLE | FLAG_MSAA_4X_HINT);
    InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Ocio");
    SetWindowMinSize(400, 300);
    SetTargetFPS(60);

    // Initial pupil position (centered)
    Vector2 currentPupilPos = { (float)WINDOW_WIDTH / 2.0f, (float)WINDOW_HEIGHT / 2.0f };

    // Version overlay state
    bool showVersionOverlay = false;

    while (!WindowShouldClose()) {
        float dt = GetFrameTime();
        if (dt > 0.1f) dt = 0.1f; // Clamp delta time during window dragging

        int screenWidth = GetScreenWidth();
        int screenHeight = GetScreenHeight();
        Vector2 eyeCenter = { (float)screenWidth / 2.0f, (float)screenHeight / 2.0f };

        // Proportional scale factor based on 800x600 reference
        float scale = fminf((float)screenWidth / 800.0f, (float)screenHeight / 600.0f);
        if (scale < 0.45f) scale = 0.45f;

        float eyeRadiusX = 220.0f * scale;
        float eyeRadiusY = 130.0f * scale;
        float irisRadius = 62.0f * scale;
        float pupilRadius = 26.0f * scale;

        // Interaction: Toggle version overlay with V
        if (IsKeyPressed(KEY_V)) {
            showVersionOverlay = !showVersionOverlay;
        }

        // --- PUPIL TRACKING LOGIC ---
        Vector2 mousePos = GetMousePosition();
        Vector2 diff = Vector2Subtract(mousePos, eyeCenter);
        float mouseDist = Vector2Length(diff);
        float angle = atan2f(diff.y, diff.x);

        // Maximum displacement for iris center within the sclera ellipse
        float maxRx = eyeRadiusX - irisRadius - 16.0f * scale;
        float maxRy = eyeRadiusY - irisRadius - 12.0f * scale;
        if (maxRx < 1.0f) maxRx = 1.0f;
        if (maxRy < 1.0f) maxRy = 1.0f;

        // Radial limit in direction of mouse along ellipse
        float cosA = cosf(angle);
        float sinA = sinf(angle);
        float denom = sqrtf((maxRy * cosA) * (maxRy * cosA) + (maxRx * sinA) * (maxRx * sinA));
        float maxDist = (denom > 0.0001f) ? (maxRx * maxRy) / denom : 0.0f;

        // Smooth saturated distance: reaches edge gracefully as mouse pulls away
        float targetDist = maxDist * tanhf(mouseDist / (240.0f * scale));

        Vector2 targetPupilPos = {
            eyeCenter.x + cosA * targetDist,
            eyeCenter.y + sinA * targetDist
        };

        // Organic smoothing (saccadic damping)
        float lerpRate = 18.0f;
        float lerpFactor = 1.0f - expf(-lerpRate * dt);
        currentPupilPos.x += (targetPupilPos.x - currentPupilPos.x) * lerpFactor;
        currentPupilPos.y += (targetPupilPos.y - currentPupilPos.y) * lerpFactor;

        // Subtle pupil dilation: slightly larger when looking at distance
        float dynamicPupilRadius = pupilRadius * (1.0f + 0.12f * (targetDist / (maxDist > 0.0f ? maxDist : 1.0f)));

        // --- RENDERING ---
        BeginDrawing();
        {
            // Background: Sleek dark canvas
            Color bgTop = (Color){ 24, 26, 33, 255 };
            ClearBackground(bgTop);

            // Ambient eye socket glow / shadow
            DrawEllipse((int)eyeCenter.x, (int)eyeCenter.y, eyeRadiusX + 28.0f * scale, eyeRadiusY + 28.0f * scale, (Color){ 16, 17, 23, 180 });
            DrawEllipse((int)eyeCenter.x, (int)eyeCenter.y, eyeRadiusX + 12.0f * scale, eyeRadiusY + 12.0f * scale, (Color){ 20, 22, 28, 220 });

            // Eyelid crease (fold) above upper lid
            Vector2 creaseStart = { eyeCenter.x - eyeRadiusX * 0.95f, eyeCenter.y - eyeRadiusY * 1.15f };
            Vector2 creaseMid   = { eyeCenter.x, eyeCenter.y - eyeRadiusY * 1.38f };
            Vector2 creaseEnd   = { eyeCenter.x + eyeRadiusX * 0.95f, eyeCenter.y - eyeRadiusY * 1.15f };
            DrawSplineBezierCubic((Vector2[]){
                creaseStart,
                (Vector2){ eyeCenter.x - eyeRadiusX * 0.4f, eyeCenter.y - eyeRadiusY * 1.38f },
                (Vector2){ eyeCenter.x + eyeRadiusX * 0.4f, eyeCenter.y - eyeRadiusY * 1.38f },
                creaseEnd
            }, 4, 2.2f * scale, (Color){ 15, 16, 21, 160 });

            // 1. Sclera (Eyeball white)
            Color scleraBase = (Color){ 248, 249, 252, 255 };
            Color scleraEdge = (Color){ 218, 224, 234, 255 };
            DrawEllipse((int)eyeCenter.x, (int)eyeCenter.y, eyeRadiusX, eyeRadiusY, scleraBase);
            // Ambient edge ring
            DrawEllipseLines((int)eyeCenter.x, (int)eyeCenter.y, eyeRadiusX, eyeRadiusY, scleraEdge);
            DrawEllipseLines((int)eyeCenter.x, (int)eyeCenter.y, eyeRadiusX - 1.0f, eyeRadiusY - 1.0f, scleraEdge);



            // Upper sclera shadow (cast by upper eyelid)
            DrawEllipse((int)eyeCenter.x, (int)(eyeCenter.y - eyeRadiusY * 0.45f), eyeRadiusX * 0.92f, eyeRadiusY * 0.48f, (Color){ 40, 45, 60, 45 });

            // 2. Iris
            // Outer limbal ring (dark definition border around iris)
            DrawCircleV(currentPupilPos, irisRadius + 2.0f * scale, (Color){ 12, 14, 20, 230 });
            // Outer iris gradient body
            DrawCircleV(currentPupilPos, irisRadius, IRIS_OUTER);
            DrawCircleV(currentPupilPos, irisRadius * 0.78f, IRIS_MID);

            // Iris radial striations (fibers)
            const int fiberCount = 36;
            for (int i = 0; i < fiberCount; i++) {
                float fiberAngle = (float)i * (2.0f * PI / (float)fiberCount);
                float fCos = cosf(fiberAngle);
                float fSin = sinf(fiberAngle);

                float innerR = dynamicPupilRadius * 0.95f;
                float outerR = irisRadius * (0.65f + 0.30f * sinf(i * 1.7f));

                Vector2 fStart = { currentPupilPos.x + fCos * innerR, currentPupilPos.y + fSin * innerR };
                Vector2 fEnd   = { currentPupilPos.x + fCos * outerR, currentPupilPos.y + fSin * outerR };

                Color fColor = (i % 2 == 0) ? IRIS_INNER : (Color){ 255, 255, 255, 70 };
                DrawLineEx(fStart, fEnd, 1.2f * scale, fColor);
            }

            // Inner collarette ring
            DrawRing(currentPupilPos, dynamicPupilRadius * 1.05f, dynamicPupilRadius * 1.25f, 0.0f, 360.0f, 40, (Color){ IRIS_INNER.r, IRIS_INNER.g, IRIS_INNER.b, 90 });

            // 3. Pupil (deep black center)
            DrawCircleV(currentPupilPos, dynamicPupilRadius, (Color){ 10, 11, 14, 255 });

            // 4. Specular Catchlights (glassy 3D eye reflections)
            // Main keylight reflection (offset top-left)
            Vector2 specMain = {
                currentPupilPos.x - irisRadius * 0.32f,
                currentPupilPos.y - irisRadius * 0.32f
            };
            DrawCircleV(specMain, 8.5f * scale, (Color){ 255, 255, 255, 230 });
            DrawCircleV(specMain, 5.0f * scale, (Color){ 255, 255, 255, 255 });

            // Secondary subtle fill reflection (offset bottom-right)
            Vector2 specSub = {
                currentPupilPos.x + irisRadius * 0.30f,
                currentPupilPos.y + irisRadius * 0.28f
            };
            DrawCircleV(specSub, 3.8f * scale, (Color){ 255, 255, 255, 140 });

            // 5. Upper Eyelid Overlay Shadow on iris/pupil
            DrawEllipse((int)eyeCenter.x, (int)(eyeCenter.y - eyeRadiusY * 0.55f), eyeRadiusX * 0.96f, eyeRadiusY * 0.45f, (Color){ 20, 22, 30, 60 });

            // 6. Eyelid Contours & Eyelashes
            // Upper eye contour (thick dark margin)
            Vector2 uP0 = { eyeCenter.x - eyeRadiusX * 1.02f, eyeCenter.y };
            Vector2 uP1 = { eyeCenter.x - eyeRadiusX * 0.50f, eyeCenter.y - eyeRadiusY * 1.10f };
            Vector2 uP2 = { eyeCenter.x + eyeRadiusX * 0.50f, eyeCenter.y - eyeRadiusY * 1.10f };
            Vector2 uP3 = { eyeCenter.x + eyeRadiusX * 1.02f, eyeCenter.y };
            DrawSplineBezierCubic((Vector2[]){ uP0, uP1, uP2, uP3 }, 4, 5.0f * scale, (Color){ 18, 19, 25, 255 });

            // Lower eye contour
            Vector2 lP0 = { eyeCenter.x - eyeRadiusX * 1.02f, eyeCenter.y };
            Vector2 lP1 = { eyeCenter.x - eyeRadiusX * 0.45f, eyeCenter.y + eyeRadiusY * 1.06f };
            Vector2 lP2 = { eyeCenter.x + eyeRadiusX * 0.45f, eyeCenter.y + eyeRadiusY * 1.06f };
            Vector2 lP3 = { eyeCenter.x + eyeRadiusX * 1.02f, eyeCenter.y };
            DrawSplineBezierCubic((Vector2[]){ lP0, lP1, lP2, lP3 }, 4, 3.0f * scale, (Color){ 28, 30, 38, 230 });

            // Eyelashes along the upper lid
            DrawUpperEyelashes(eyeCenter, eyeRadiusX, eyeRadiusY, scale);

            // Outer eye corner rims
            DrawCircleLines((int)(eyeCenter.x - eyeRadiusX * 1.0f), (int)eyeCenter.y, 3.0f * scale, (Color){ 45, 48, 60, 180 });
            DrawCircleLines((int)(eyeCenter.x + eyeRadiusX * 1.0f), (int)eyeCenter.y, 3.0f * scale, (Color){ 45, 48, 60, 180 });

            // --- HUD & CONTROLS OVERLAY ---
            int fontSize = (int)(15.0f * fmaxf(scale, 0.85f));

            // Version Overlay (toggled with V or displayed while holding V)
            if (showVersionOverlay || IsKeyDown(KEY_V)) {
                char verStr[64];
                snprintf(verStr, sizeof(verStr), "Ocio v%s", APP_VERSION);
                int vFontSize = (int)(16.0f * fmaxf(scale, 0.85f));
                int textW = MeasureText(verStr, vFontSize);
                int padH = 14;
                int padV = 8;
                int boxW = textW + padH * 2;
                int boxH = vFontSize + padV * 2;
                int boxX = screenWidth - boxW - 20;
                int boxY = 20;

                // Semi-transparent rounded card with subtle blue rim
                DrawRectangleRounded((Rectangle){ (float)boxX, (float)boxY, (float)boxW, (float)boxH }, 0.35f, 6, (Color){ 25, 28, 38, 235 });
                DrawRectangleRoundedLinesEx((Rectangle){ (float)boxX, (float)boxY, (float)boxW, (float)boxH }, 0.35f, 6, 1.5f, (Color){ 70, 130, 210, 220 });
                DrawText(verStr, boxX + padH, boxY + padV, vFontSize, (Color){ 220, 235, 255, 255 });
            }

            // Instructions (bottom-center)
            const char *helpText = "Move mouse to direct gaze  •  [V] Version  •  ESC to quit";
            int helpWidth = MeasureText(helpText, fontSize);
            DrawText(helpText, (screenWidth - helpWidth) / 2, screenHeight - 34, fontSize, (Color){ 140, 150, 170, 200 });

            // Crosshair dot at mouse position for tracking feedback
            DrawCircleV(mousePos, 4.0f, (Color){ 255, 255, 255, 120 });
            DrawCircleLines((int)mousePos.x, (int)mousePos.y, 8.0f, (Color){ 255, 255, 255, 80 });
        }
        EndDrawing();
    }

    CloseWindow();
    return 0;
}
