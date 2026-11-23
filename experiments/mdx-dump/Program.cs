// Dumps the shape of types in the real Managed DirectX assemblies, for matching a shim to them:
// kind, base type, layout, fields (enum values), and every public member's signature.
// usage: mdx-dump <ref dir> <net48 reference assembly dir> <type name>...   (simple or full names)
using System.Reflection;

var refDir = args[0]; var fxDir = args[1];
var paths = Directory.GetFiles(fxDir, "*.dll").Concat(Directory.GetFiles(refDir, "*.dll"));
using var mlc = new MetadataLoadContext(new PathAssemblyResolver(paths), "mscorlib");
var types = Directory.GetFiles(refDir, "*.dll").SelectMany(p => {
    var a = mlc.LoadFromAssemblyPath(p);
    try { return a.GetTypes(); } catch (ReflectionTypeLoadException e) { return e.Types.Where(t => t != null); }
}).ToList();
const BindingFlags all = BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance | BindingFlags.Static | BindingFlags.DeclaredOnly;
string N(Type t) => t == null ? "?" : t.IsGenericType ? t.Name : (t.IsNested ? N(t.DeclaringType) + "+" : "") + t.Name;
string P(ParameterInfo p) => (p.ParameterType.IsByRef ? (p.IsOut ? "out " : "ref ") + N(p.ParameterType.GetElementType()) : N(p.ParameterType)) + " " + p.Name;
foreach (var name in args.Skip(2)) {
    foreach (var t in types.Where(x => x.FullName == name || x.Name == name || N(x) == name)) {
        string kind = t.IsEnum ? "enum" : t.IsValueType ? "struct" : t.IsInterface ? "interface" : t.IsAbstract && t.IsSealed ? "static class" : (t.IsSealed ? "sealed " : "") + (t.IsAbstract ? "abstract " : "") + "class";
        var sl = t.StructLayoutAttribute;
        Console.WriteLine($"=== {t.Assembly.GetName().Name}: {kind} {t.FullName} : {N(t.BaseType)} {(t.GetInterfaces().Length > 0 ? "[" + string.Join(",", t.GetInterfaces().Select(N)) + "]" : "")} layout={sl?.Value} pack={sl?.Pack} size={sl?.Size}");
        if (t.IsEnum) {
            Console.WriteLine("  underlying " + N(Enum.GetUnderlyingType(t)) + (t.GetCustomAttributesData().Any(a => a.AttributeType.Name == "FlagsAttribute") ? " [Flags]" : ""));
            foreach (var f in t.GetFields(BindingFlags.Public | BindingFlags.Static)) Console.WriteLine($"  {f.Name} = {f.GetRawConstantValue()}");
            continue;
        }
        foreach (var f in t.GetFields(all)) Console.WriteLine($"  field {(f.IsPublic ? "public" : "private")}{(f.IsStatic ? " static" : "")} {N(f.FieldType)} {f.Name}");
        foreach (var c in t.GetConstructors(all).Where(c => c.IsPublic)) Console.WriteLine($"  ctor({string.Join(", ", c.GetParameters().Select(P))})");
        foreach (var p in t.GetProperties(all)) {
            var g = p.GetGetMethod(); var s = p.GetSetMethod();
            if (g == null && s == null) continue;
            Console.WriteLine($"  prop {((g ?? s).IsStatic ? "static " : "")}{N(p.PropertyType)} {p.Name}{(p.GetIndexParameters().Length > 0 ? "[" + string.Join(",", p.GetIndexParameters().Select(P)) + "]" : "")} {{{(g != null ? " get;" : "")}{(s != null ? " set;" : "")} }}");
        }
        foreach (var e in t.GetEvents(all)) Console.WriteLine($"  event {N(e.EventHandlerType)} {e.Name}");
        foreach (var m in t.GetMethods(all).Where(m => m.IsPublic && !m.IsSpecialName || m.Name.StartsWith("op_"))) Console.WriteLine($"  {(m.IsStatic ? "static " : "")}{(m.IsVirtual ? "virtual " : "")}{N(m.ReturnType)} {m.Name}({string.Join(", ", m.GetParameters().Select(P))})");
    }
}
