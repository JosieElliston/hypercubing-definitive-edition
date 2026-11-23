// Build step for the MDX shim: adds custom modifiers that C# can't emit.
//
// The real MDX is C++/CLI, so some of its signatures carry modopts, e.g. CustomVertex
// .PositionColored.get_StrideSize returns `int modopt(Microsoft.VisualC.IsConstModifier)`.
// The programs' member references copy that signature, and Mono only binds a reference to a
// method whose modifiers match (MissingMethodException otherwise).
//
// Source marks such a return value with [return: ReturnModOpt(typeof(X))]; this tool rewrites
// the return type to `T modopt(X)` and removes the marker. Running it twice is harmless.
// usage: AddModOpt <assembly.dll>   (rewritten in place; the public key and flags are kept)
using Mono.Cecil;

var path = args[0];
var bytes = File.ReadAllBytes(path);
using var module = ModuleDefinition.ReadModule(new MemoryStream(bytes));
int n = 0;
foreach (var type in module.GetTypes())
    foreach (var m in type.Methods)
    {
        var attrs = m.MethodReturnType.CustomAttributes;
        var a = attrs.FirstOrDefault(x => x.AttributeType.Name == "ReturnModOptAttribute");
        if (a == null) continue;
        var mod = module.ImportReference((TypeReference)a.ConstructorArguments[0].Value);
        m.ReturnType = new OptionalModifierType(mod, m.ReturnType);
        attrs.Remove(a);
        n++;
    }
if (n == 0) return;
module.Write(path);
Console.WriteLine($"AddModOpt: {n} return types in {Path.GetFileName(path)}");
