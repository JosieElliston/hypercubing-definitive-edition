package jzzz;

import com.jogamp.opengl.GL2;
import java.nio.FloatBuffer;
import java.nio.IntBuffer;
import java.nio.ShortBuffer;

final class LegacyShaderRenderer {
    private static final int CUBE_FACE_TRIANGLES = 192;
    private static final int CUBE_MESH_TRIANGLES = 768;
    private static final int PIECE_VERTICES = 96;
    private static final int FIRST_CENTER = 26 + PIECE_VERTICES;
    private static final int VERTICES_PER_STATE = FIRST_CENTER + 8;

    // Evaluate the original shaders' mesh indices on the CPU. The game still supplies the
    // current vertices, orientation, stickers and the temporary geometry for turns and splits.
    static void draw48(float[] model, FloatBuffer vertices, FloatBuffer palette,
                       IntBuffer colors, IntBuffer indices, int vertexCount) {
        var gl = CGL.gl_;
        begin(gl);
        try {
            for (int i = 0; i < vertexCount; i++) {
                int index = indices.get(i);
                int vertex = (index & 0xffff) * 3;
                int color = colors.get((index >>> 16) & 0xff) * 3;
                gl.glColor3f(palette.get(color), palette.get(color + 1), palette.get(color + 2));
                float x = vertices.get(vertex);
                float y = vertices.get(vertex + 1);
                float z = vertices.get(vertex + 2);
                gl.glNormal3f(model[0] * x + model[3] * y + model[6] * z,
                             model[1] * x + model[4] * y + model[7] * z,
                             model[2] * x + model[5] * y + model[8] * z);
                vertex(gl, model, x, y, z);
            }
        } finally {
            end(gl);
        }
    }

    static void draw192(float[] model, float[] vertices, float[] palette, int[] colors,
                        int[] faces, int[] splits, int[] splitNormals, int[] pieceMasks,
                        int axis, ShortBuffer elements, int vertexCount) {
        var gl = CGL.gl_;
        begin(gl);
        try {
            for (int i = 0; i < vertexCount; i++) {
                int vertexId = elements == null ? i : Short.toUnsignedInt(elements.get(i));
                int triangle = vertexId / 3;
                int corner = vertexId % 3;
                int color = 0;
                if (triangle < CUBE_FACE_TRIANGLES) {
                    color = 4 + (colors[triangle] & 0xff);
                } else if (triangle >= CUBE_MESH_TRIANGLES) {
                    color = 2;
                }
                color *= 3;
                gl.glColor3f(palette[color], palette[color + 1], palette[color + 2]);

                int index;
                int normal;
                int cornerVertex;
                int center;
                if (triangle < CUBE_MESH_TRIANGLES) {
                    int piece = (faces[triangle / 4] >>> ((triangle % 4) * 8)) & 0xff;
                    if (triangle >= CUBE_FACE_TRIANGLES) {
                        corner = corner == 0 ? 3 : (4 - triangle % 3 - corner) % 3;
                        int edge = (triangle - CUBE_FACE_TRIANGLES) / 48;
                        normal = edge < 6 ? 7 + edge : 31 - edge;
                    } else {
                        int face = triangle / 32;
                        normal = face < 3 ? face : 18 - face;
                    }
                    index = piece * 4 + corner;
                    center = FIRST_CENTER + index / PIECE_VERTICES;
                    cornerVertex = 26 + index % PIECE_VERTICES;
                    int pieceType = (pieceMasks[piece / 8] >>> ((piece % 8) * 4)) & 15;
                    if ((pieceType & 8) != 0) {
                        int rotatingCenter = pieceType & 7;
                        center = VERTICES_PER_STATE + FIRST_CENTER + rotatingCenter;
                        boolean evenAxis = switch (rotatingCenter) {
                            case 0, 2, 5, 7 -> true;
                            default -> false;
                        };
                        if (((axis & 1) == 0) == evenAxis) {
                            cornerVertex += VERTICES_PER_STATE;
                            normal += VERTICES_PER_STATE;
                        }
                    }
                } else {
                    int split = triangle - CUBE_MESH_TRIANGLES;
                    int slot = (splits[corner] >>> ((split % 4) * 4)) & 15;
                    slot = ((slot + (split & 12)) & 15) + (split & 16);
                    int pair = splits[4 + axis * splits[3] + slot / 2];
                    index = (pair >>> ((slot % 2) * 16)) & 0xffff;
                    center = FIRST_CENTER + index / PIECE_VERTICES;
                    cornerVertex = 26 + index % PIECE_VERTICES;
                    int normalSlot = (split / 2) % 8;
                    normal = (splitNormals[axis * 2 + normalSlot / 4] >>> ((normalSlot % 4) * 8)) & 0xff;
                }
                int n = normal * 3;
                int c = center * 3;
                int v = cornerVertex * 3;
                gl.glNormal3f(vertices[n], vertices[n + 1], vertices[n + 2]);
                vertex(gl, model, vertices[c] + vertices[v],
                    vertices[c + 1] + vertices[v + 1], vertices[c + 2] + vertices[v + 2]);
            }
        } finally {
            end(gl);
        }
    }

    static void draw8x24(float[] vertices, float[] palette, int[] colors, int[] splits,
                         int axis, int vertexCount) {
        var gl = CGL.gl_;
        begin(gl);
        try {
            for (int i = 0; i < vertexCount; i++) {
                int index, normal, color;
                boolean back;
                if (i >= CUBE_MESH_TRIANGLES * 3) {
                    int splitAxis = (axis >>> 4) & 7;
                    if (splitAxis > 2) splitAxis = 5 - splitAxis;
                    int split = splits[splitAxis * 48 + i - CUBE_MESH_TRIANGLES * 3];
                    index = split & 0xffff;
                    normal = split >>> 16;
                    back = normal > 8;
                    if (back) normal -= 9;
                    color = 2;
                } else {
                    int triangle = i / 3;
                    int corner = i % 3;
                    int face = triangle % 4;
                    int piece = triangle / 4;
                    int layer = piece & 16;
                    int offset = IGl8x24Cube.pieceIndices1_[(axis & 15) * 6 + piece / 32] | layer;
                    int shape = IGl8x24Cube.pieceIndices0_[offset + (piece & 15)];
                    if (face != 0) corner = corner == 0 ? 3 : (face + 2 - corner) % 3;
                    index = shape * 4 + corner;
                    if ((axis & 0x100) != 0 && shape < 96) {
                        int movingNormal = (IGl8x24Cube.normalIndices2_[shape] >>> (face * 8)) & 0xff;
                        back = (movingNormal & 16) != 0;
                        normal = ((movingNormal & 32) == 0 ? 16 : (2 + shape / 24) * 16)
                            + (movingNormal & 15);
                    } else {
                        int orientation = ((shape / 24) & 3) * 24 + shape % 24;
                        int normalOffset = (IGl8x24Cube.normalIndices_[orientation] >>> 6) & 0x03fc;
                        normal = IGl8x24Cube.normalIndices_[normalOffset + face] & 0xff;
                        back = normal > 8;
                        if (back) normal -= 9;
                    }
                    color = face == 0 ? 4 + colors[piece] : 0;
                }
                int c = color * 3;
                int n = (CUBE_MESH_TRIANGLES + normal) * 3;
                int v = index * 3;
                float sign = back ? -1 : 1;
                gl.glColor3f(palette[c], palette[c + 1], palette[c + 2]);
                gl.glNormal3f(sign * vertices[n], sign * vertices[n + 1], sign * vertices[n + 2]);
                gl.glVertex3f(vertices[v], vertices[v + 1], vertices[v + 2]);
            }
        } finally {
            end(gl);
        }
    }

    private static void vertex(GL2 gl, float[] model, float x, float y, float z) {
        gl.glVertex3f(model[0] * x + model[3] * y + model[6] * z,
                      model[1] * x + model[4] * y + model[7] * z,
                      model[2] * x + model[5] * y + model[8] * z);
    }

    private static void begin(GL2 gl) {
        gl.glPushAttrib(GL2.GL_ENABLE_BIT | GL2.GL_LIGHTING_BIT | GL2.GL_CURRENT_BIT);
        gl.glEnable(GL2.GL_NORMALIZE);
        gl.glColorMaterial(GL2.GL_FRONT, GL2.GL_AMBIENT_AND_DIFFUSE);
        gl.glEnable(GL2.GL_COLOR_MATERIAL);
        gl.glBegin(GL2.GL_TRIANGLES);
    }

    private static void end(GL2 gl) {
        gl.glEnd();
        gl.glPopAttrib();
    }
}
