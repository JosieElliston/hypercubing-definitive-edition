#import <AppKit/AppKit.h>
#include <jni.h>

static NSString *fromJava(JNIEnv *env, jstring string) {
    jsize length = (*env)->GetStringLength(env, string);
    const jchar *characters = (*env)->GetStringChars(env, string, NULL);
    if (characters == NULL) return nil;
    NSString *result = [NSString stringWithCharacters:characters length:length];
    (*env)->ReleaseStringChars(env, string, characters);
    return result;
}

static jstring toJava(JNIEnv *env, NSString *string) {
    if (string == nil) return NULL;
    if (string.length == 0) return (*env)->NewStringUTF(env, "");
    NSData *data = [string dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
    return (*env)->NewString(env, data.bytes, (jsize)string.length);
}

static NSString *chooseFile(BOOL save, NSString *directory) {
    NSSavePanel *panel = save ? [NSSavePanel savePanel] : [NSOpenPanel openPanel];
    panel.directoryURL = [NSURL fileURLWithPath:directory isDirectory:YES];
    return [panel runModal] == NSModalResponseOK ? panel.URL.path : nil;
}

static NSModalResponse alert(NSString *message, NSString *details, NSArray<NSString *> *buttons) {
    NSAlert *panel = [[NSAlert alloc] init];
    panel.messageText = message;
    panel.informativeText = details;
    for (NSString *button in buttons) [panel addButtonWithTitle:button];
    return [panel runModal];
}

static NSString *runDialog(NSString *mode, NSString *saves, NSString *details) {
    if ([mode isEqualToString:@"open"] || [mode isEqualToString:@"save"]) {
        return chooseFile([mode isEqualToString:@"save"], saves);
    }
    if ([mode isEqualToString:@"close"]) {
        NSModalResponse choice = alert(@"Save changes before closing?", @"",
                                       @[@"Save", @"Cancel", @"Don’t Save"]);
        if (choice == NSAlertFirstButtonReturn) return chooseFile(YES, saves);
        return choice == NSAlertThirdButtonReturn ? @"" : nil;
    }
    if ([mode isEqualToString:@"error"]) {
        alert(@"ElevenCell3D could not complete the operation", details, @[@"OK"]);
        return nil;
    }
    BOOL scramble = [mode isEqualToString:@"scramble"];
    NSModalResponse choice = alert(scramble ? @"Scramble the puzzle?" : @"Reset the puzzle?",
                                   @"", @[scramble ? @"Scramble" : @"Reset", @"Cancel"]);
    return choice == NSAlertFirstButtonReturn ? @"" : nil;
}

// Null means canceled. A selected path is returned verbatim. An empty string
// confirms a command without a file, including closing without saving.
JNIEXPORT jstring JNICALL Java_Main_runDialog(JNIEnv *env, jobject self, jstring operation,
                                             jstring saves, jstring details) {
    @autoreleasepool {
        NSWindow *puzzleWindow = NSApp.keyWindow ?: NSApp.mainWindow;
        NSString *path = runDialog(fromJava(env, operation), fromJava(env, saves),
                                   fromJava(env, details));
        if (NSApp.active) [puzzleWindow makeKeyWindow];
        return toJava(env, path);
    }
}
