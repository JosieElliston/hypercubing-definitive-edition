package jzzz;

import jgeo.CMatrix3F;
import jgeo.CMatrix3_;

// The fixed-function renderer from v1.20985, adapted to the byte color table in v1.21058.
final class LegacyDodecaRenderer {
    private static final int TWISTING = 0x40000000;
    private static final int CORNERS_PER_CELL = 20;
    private static final int VERTICES_PER_CORNER = 12;

    static void draw(CGlCornersDodecasDodeca puzzle, int[][] twistMasks, int twist,
                     int[][] triangles) {
        var model = new CMatrix3F();
        var vertices = puzzle.verticesIn_;
        var transformed = puzzle.vs0_;
        boolean turning = (CGlObj.state_ & TWISTING) != 0;
        if (turning) {
            var rotation = new CMatrix3F();
            puzzle.SetDrawMatrices(rotation, model);
            CMatrix3_.apply_(rotation.m_, vertices, transformed, 0, vertices.length, vertices.length);
        } else {
            puzzle.SetDrawMatrices(model);
        }
        CMatrix3_.apply_(model.m_, vertices, transformed, vertices.length);

        int halfCells = vertices.length / 3 - VERTICES_PER_CORNER * (CORNERS_PER_CELL / 2);
        int cells = halfCells * 2;
        for (int piece : puzzle.cornerIndices_) {
            int corner = piece % CORNERS_PER_CELL;
            int cell = piece / CORNERS_PER_CELL;
            int mask = (twistMasks[twist & 15][piece / 8] >>> ((piece % 8) * 4)) & 15;
            int motion = turning ? mask : 0;
            boolean reverseCorner = corner >= CORNERS_PER_CELL / 2;
            boolean reverseCell = cell >= halfCells;
            int center = (reverseCell ? cells - 1 - cell : cell) * 3;
            if ((motion & 2) != 0) center += vertices.length;
            float cellSign = reverseCell ? -1 : 1;
            float cx = transformed[center] * cellSign;
            float cy = transformed[center + 1] * cellSign;
            float cz = transformed[center + 2] * cellSign;
            int firstVertex = (halfCells + VERTICES_PER_CORNER *
                (reverseCorner ? CORNERS_PER_CELL - 1 - corner : corner)) * 3;
            if ((motion & 1) != 0) firstVertex += vertices.length;
            float cornerSign = reverseCorner ? -1 : 1;

            for (int part = 0; part < triangles.length; part++) {
                int facet = part < 2 ? part : 1 + part / 2;
                int color;
                if (facet >= 2 && facet <= 4) {
                    int sticker = facet - 2;
                    if (reverseCorner && sticker != 0) sticker = 3 - sticker;
                    int stickerColor = puzzle.colors_[piece * 3 + sticker];
                    if (stickerColor == 12) continue;
                    color = 4 + stickerColor;
                } else {
                    color = mask != 0 ? 3 : (facet == 1 || facet >= 8 ? 0 : 1);
                }

                CGL.setAmbient_(color);
                CGL.glBegin();
                for (int i = 0; i < 3; i++) {
                    int index = firstVertex + 3 * triangles[part][reverseCorner && i != 0 ? 3 - i : i];
                    float x = cx + cornerSign * transformed[index];
                    float y = cy + cornerSign * transformed[index + 1];
                    float z = cz + cornerSign * transformed[index + 2];
                    var gl = CGL.gl_;
                    float radius = (float) Math.sqrt(x * x + y * y + z * z);
                    gl.glNormal3f(x / radius, y / radius, z / radius);
                    gl.glVertex3f(x, y, z);
                }
                CGL.glEnd();
            }
        }
    }
}
