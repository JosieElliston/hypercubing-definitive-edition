package jzzz;

import com.jogamp.opengl.GL2;
import java.nio.IntBuffer;
import jgeo.CMatrix3F;
import jgeo.CMatrix3_;

final class LegacyCubeRenderer {
    private static final int TWISTING = 0x40000000;
    private static final int TRIANGLES_PER_CORNER = 22;
    private static final int VERTICES_PER_CORNER = 13;

    // Use the same mesh, sticker colors and layer rotations as CGl8x8Cube's vertex shader.
    static void draw(CGl8x8Cube cube, CMatrix3F baseModel, int twist, float[] vertices,
                     float[] palette, int[] attributes, IntBuffer stickers, IntBuffer triangles,
                     IntBuffer corners, IntBuffer vertexIndices, IntBuffer normalIndices) {
        if ((CGlObj.state_ & TWISTING) != 0) {
            cube.countTwistTime0();
        }

        var model = new CMatrix3F(baseModel);
        model.scale_(1.0 / Math.sqrt(3.0));
        model.mul_(CCubeInterface.mv_);
        cube.SetDrawMatrices(model);

        int face = twist & 7;
        int rotated = vertices.length / 6;
        if ((CGlObj.state_ & TWISTING) != 0) {
            rotateVertices(cube, vertices, face, rotated * 3);
        }

        var gl = CGL.gl_;
        gl.glPushMatrix();
        gl.glMultMatrixf(new float[]{
            model.m_[0], model.m_[1], model.m_[2], 0,
            model.m_[3], model.m_[4], model.m_[5], 0,
            model.m_[6], model.m_[7], model.m_[8], 0,
            0, 0, 0, 1
        }, 0);
        gl.glPushAttrib(GL2.GL_ENABLE_BIT | GL2.GL_LIGHTING_BIT | GL2.GL_CURRENT_BIT);
        gl.glEnable(GL2.GL_NORMALIZE);
        gl.glColorMaterial(GL2.GL_FRONT, GL2.GL_AMBIENT_AND_DIFFUSE);
        gl.glEnable(GL2.GL_COLOR_MATERIAL);
        gl.glBegin(GL2.GL_TRIANGLES);
        for (int piece = 0; piece < 64; piece++) {
            int corner = piece / 8;
            int shape = piece % 8;
            int layer = layerForFace(attributes[piece], face);
            boolean turnPiece = (twist & TWISTING) != 0 && layer == 2;
            boolean turnCenter = (twist & TWISTING) != 0 && layer >= 2;
            int center = (corners.get(corner) + (turnCenter ? rotated : 0)) * 3;

            for (int triangle = 0; triangle < TRIANGLES_PER_CORNER; triangle++) {
                int color = 0;
                int normal;
                if (triangle < 6) {
                    color = 4 + stickers.get(attributes[64 + (triangle / 2) * 64 + piece]);
                    normal = 1 + triangle / 2;
                } else if (triangle < 12) {
                    normal = 4 + (triangle - 6) / 2;
                } else if (triangle < 21) {
                    int part = (triangle - 12) / 3;
                    int sticker = attributes[64 + part * 64 + piece];
                    int stickerFace = sticker >> 5;
                    int stickerLayer = (sticker >> 4) & 1;
                    if (stickerFace == (stickerLayer == 0 ? face : 5 - face)) {
                        color = 2;
                    }
                    normal = 7 + part;
                } else {
                    normal = 0;
                }

                int n = (normalIndices.get(normal * 8 + shape) + (turnPiece ? rotated : 0)) * 3;
                gl.glColor3f(palette[color * 3], palette[color * 3 + 1], palette[color * 3 + 2]);
                gl.glNormal3f(vertices[n], vertices[n + 1], vertices[n + 2]);
                for (int i = 0; i < 3; i++) {
                    int vertex = vertexIndices.get(shape * VERTICES_PER_CORNER + triangles.get(triangle * 3 + i));
                    int v = (vertex + (turnPiece ? rotated : 0)) * 3;
                    gl.glVertex3f(vertices[v] + vertices[center],
                        vertices[v + 1] + vertices[center + 1], vertices[v + 2] + vertices[center + 2]);
                }
            }
        }
        gl.glEnd();
        gl.glPopAttrib();
        gl.glPopMatrix();

        cube.DrawArrows();
        if ((CGlObj.state_ & TWISTING) != 0) {
            cube.countTwistTime1();
        }
    }

    private static int layerForFace(int attributes, int face) {
        return switch (face) {
            case 0 -> (attributes >> 3) & 7;
            case 1 -> attributes >> 6;
            case 2 -> 3 - (attributes & 7);
            case 3 -> attributes & 7;
            case 4 -> 3 - (attributes >> 6);
            case 5 -> 3 - ((attributes >> 3) & 7);
            default -> 0;
        };
    }

    private static void rotateVertices(CGl8x8Cube cube, float[] vertices, int face, int offset) {
        float phase = (float) cube.twistTimer_.phase_;
        if (cube.twistDir_) {
            phase = -phase;
        }
        if (face == 2 || face == 4 || face == 5) {
            phase = -phase;
        }
        var rotation = new CMatrix3F();
        switch (face) {
            case 0, 5 -> rotation.rotateY_(phase);
            case 1, 4 -> rotation.rotateZ_(phase);
            default -> rotation.rotateX_(phase);
        }
        int half = offset / 2;
        CMatrix3_.apply_(rotation.m_, vertices, vertices, 0, offset, half);
        for (int i = 0; i < half; i++) {
            vertices[offset + half + i] = -vertices[offset + i];
        }
    }
}
