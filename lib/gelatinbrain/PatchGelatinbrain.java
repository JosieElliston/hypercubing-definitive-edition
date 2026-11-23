import java.io.IOException;
import java.lang.classfile.ClassFile;
import java.lang.classfile.ClassTransform;
import java.lang.classfile.CodeBuilder;
import java.lang.classfile.CodeElement;
import java.lang.classfile.CodeTransform;
import java.lang.classfile.instruction.InvokeInstruction;
import java.lang.constant.ClassDesc;
import java.lang.constant.MethodTypeDesc;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.List;
import java.util.Set;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;
import java.util.zip.ZipOutputStream;

import static java.lang.constant.ConstantDescs.CD_boolean;
import static java.lang.constant.ConstantDescs.CD_float;
import static java.lang.constant.ConstantDescs.CD_int;
import static java.lang.constant.ConstantDescs.CD_void;

// Apply the renderer fallbacks to the pinned game JAR during packaging.
class PatchGelatinbrain {
    private static final String ORIGINAL_SHA256 =
        "1311f9fcb7c0e1da01cf5bce87836492974da005dac2f5416013c306684427ac";
    private static final ClassDesc DODECA = ClassDesc.of("jzzz.CGlCornersDodecasDodeca");
    private static final ClassDesc CUBE = ClassDesc.of("jzzz.CGl8x8Cube");
    private static final ClassDesc OLD_FLOAT_UTIL = ClassDesc.of("com.jogamp.opengl.math.FloatUtil");
    private static final ClassDesc FLOAT_UTIL = ClassDesc.of("com.jogamp.math.FloatUtil");

    private static final ClassDesc LEGACY_CUBE = ClassDesc.of("jzzz.LegacyCubeRenderer");
    private static final ClassDesc LEGACY_DODECA = ClassDesc.of("jzzz.LegacyDodecaRenderer");
    private static final ClassDesc LEGACY_SHADER = ClassDesc.of("jzzz.LegacyShaderRenderer");
    private static final ClassDesc INT_MATRIX = CD_int.arrayType().arrayType();
    private static final ClassDesc MATRIX = ClassDesc.of("jgeo.CMatrix3F");
    private static final ClassDesc INT_BUFFER = ClassDesc.of("java.nio.IntBuffer");
    private static final ClassDesc FLOAT_ARRAY = CD_float.arrayType();

    public static void main(String[] args) throws IOException, NoSuchAlgorithmException {
        var source = Path.of(args[0]);
        var hash = MessageDigest.getInstance("SHA-256").digest(Files.readAllBytes(source));
        if (!HexFormat.of().formatHex(hash).equals(ORIGINAL_SHA256)) {
            throw new IOException("Unexpected Gelatinbrain game jar: " + source);
        }
        var renderers = Set.of(DODECA, CUBE, ClassDesc.of("jzzz.CGlSpongy3x3x3Cube"));
        var classes = Path.of(args[2]);
        try (var input = new ZipInputStream(Files.newInputStream(source));
             var output = new ZipOutputStream(Files.newOutputStream(Path.of(args[1])))) {
            ZipEntry entry;
            int patched = 0;
            while ((entry = input.getNextEntry()) != null) {
                var copy = new ZipEntry(entry.getName());
                copy.setTime(entry.getTime());
                output.putNextEntry(copy);
                var replacement = classes.resolve(copy.getName());
                ClassDesc renderer = renderers.stream()
                    .filter(type -> entryName(type).equals(copy.getName())).findFirst().orElse(null);
                if (Files.isRegularFile(replacement)) {
                    Files.copy(replacement, output);
                } else if (renderer == null) {
                    input.transferTo(output);
                } else {
                    output.write(patch(input.readAllBytes(), renderer));
                    patched++;
                }
                output.closeEntry();
            }
            for (var renderer : List.of(LEGACY_CUBE, LEGACY_DODECA, LEGACY_SHADER)) {
                var fallback = new ZipEntry(entryName(renderer));
                fallback.setTime(0);
                output.putNextEntry(fallback);
                Files.copy(classes.resolve(entryName(renderer)), output);
                output.closeEntry();
            }
            if (patched != renderers.size()) {
                throw new IOException("Expected all Gelatinbrain renderer classes");
            }
        }
    }

    private static String entryName(ClassDesc type) {
        return type.descriptorString().substring(1, type.descriptorString().length() - 1) + ".class";
    }

    private static byte[] patch(byte[] bytes, ClassDesc type) {
        var files = ClassFile.of();
        // JogAmp moved this class. The shader path still calls it where GLSL 1.30 works.
        var relocateFloatUtil = ClassTransform.transformingMethodBodies((code, element) -> {
            if (element instanceof InvokeInstruction call
                    && call.owner().asSymbol().equals(OLD_FLOAT_UTIL)) {
                code.invokestatic(FLOAT_UTIL, call.name().stringValue(), call.typeSymbol());
            } else {
                code.with(element);
            }
        });
        byte[] relocated = files.transformClass(files.parse(bytes), relocateFloatUtil);
        if (type.equals(DODECA)) {
            var useDodecaFallback = ClassTransform.transformingMethodBodies(
                method -> method.methodName().equalsString("Draw"), (code, element) -> {
                    if (element instanceof InvokeInstruction call && call.name().equalsString("DrawWithShader")) {
                        // The original call has already pushed this. Reuse it on either branch.
                        var fallback = code.newLabel();
                        var done = code.newLabel();
                        shaderReady(code, type);
                        code.ifeq(fallback).with(element).goto_(done)
                            .labelBinding(fallback)
                            .aload(0).getfield(DODECA, "twistMasks_", INT_MATRIX)
                            .aload(0).getfield(DODECA, "twno_", CD_int)
                            .getstatic(DODECA, "triangleIndices_", INT_MATRIX)
                            .invokestatic(LEGACY_DODECA, "draw",
                                MethodTypeDesc.of(CD_void, DODECA, INT_MATRIX, CD_int, INT_MATRIX))
                            .labelBinding(done);
                    } else {
                        code.with(element);
                    }
                });
            return files.transformClass(files.parse(relocated), useDodecaFallback);
        }
        if (type.equals(CUBE)) {
            var useCubeFallback = ClassTransform.transformingMethodBodies(
                method -> method.methodName().equalsString("Draw"), new CodeTransform() {
                    @Override
                    public void atStart(CodeBuilder code) {
                        var useShader = code.newLabel();
                        shaderReady(code, CUBE);
                        code.ifne(useShader).aload(0)
                            .aload(0).getfield(CUBE, "modelMatrix0_", MATRIX)
                            .aload(0).getfield(CUBE, "twno_", CD_int)
                            .aload(0).getfield(CUBE, "vertices0_", FLOAT_ARRAY)
                            .aload(0).getfield(CUBE, "colorTable_", FLOAT_ARRAY)
                            .getstatic(CUBE, "attributes_", CD_int.arrayType());
                        for (String field : new String[]{"cibuf_", "tibuf_", "oibuf_", "vibuf_", "nibuf_"}) {
                            code.aload(0).getfield(CUBE, field, INT_BUFFER);
                        }
                        code.invokestatic(LEGACY_CUBE, "draw", MethodTypeDesc.of(CD_void, CUBE,
                            MATRIX, CD_int, FLOAT_ARRAY, FLOAT_ARRAY, CD_int.arrayType(),
                            INT_BUFFER, INT_BUFFER, INT_BUFFER, INT_BUFFER, INT_BUFFER))
                            .return_().labelBinding(useShader);
                    }

                    @Override
                    public void accept(CodeBuilder code, CodeElement element) {
                        code.with(element);
                    }
                });
            return files.transformClass(files.parse(relocated), useCubeFallback);
        }
        return relocated;
    }

    private static void shaderReady(CodeBuilder code, ClassDesc renderer) {
        var shader = renderer.nested("CMyShaderProgram");
        var firstSide = code.newLabel();
        var select = code.newLabel();
        code.aload(0).getfield(renderer, "shaders_", shader.arrayType())
            .aload(0).getfield(renderer, "side_", CD_boolean).ifeq(firstSide)
            .iconst_1().goto_(select).labelBinding(firstSide).iconst_0().labelBinding(select)
            .aaload().invokevirtual(shader, "isInitialized", MethodTypeDesc.of(CD_boolean));
    }
}
