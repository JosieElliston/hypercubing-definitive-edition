// Lists every type and member an assembly references from Microsoft.DirectX* assemblies.
// usage: mdx-surface [--sig] <exe>...   (prints "assembly | type | member" lines, deduplicated)
//   --sig  print each member's full signature (return type, parameter types), so overloads
//          show up separately.
//   mdx-surface --defs <dll>...  prints what the given assemblies define, in the --sig format.
//   Diff the two to check a shim: `comm -23 <(mdx-surface --sig exes) <(mdx-surface --defs dlls)`.
using System.Collections.Immutable;
using System.Reflection.Metadata;
using System.Reflection.PortableExecutable;

bool sig = args.Length > 0 && args[0] == "--sig";
var lines = new SortedSet<string>();
if (args.Length > 0 && args[0] == "--defs") { Defs(args.Skip(1)); return; }
foreach (var path in args.Where(a => a != "--sig"))
{
    using var pe = new PEReader(File.OpenRead(path));
    var md = pe.GetMetadataReader();
    string Scope(EntityHandle h) => h.Kind switch
    {
        HandleKind.AssemblyReference => md.GetString(md.GetAssemblyReference((AssemblyReferenceHandle)h).Name),
        HandleKind.TypeReference => Scope(md.GetTypeReference((TypeReferenceHandle)h).ResolutionScope),
        _ => "",
    };
    string TypeName(TypeReferenceHandle h)
    {
        var t = md.GetTypeReference(h);
        var outer = t.ResolutionScope.Kind == HandleKind.TypeReference ? TypeName((TypeReferenceHandle)t.ResolutionScope) + "+" : md.GetString(t.Namespace) + ".";
        return outer + md.GetString(t.Name);
    }
    var prov = new Prov(md, TypeName);
    foreach (var h in md.TypeReferences)
    {
        var s = Scope(h);
        if (s.StartsWith("Microsoft.DirectX")) lines.Add($"{s} | {TypeName(h)} | (type)");
    }
    foreach (var h in md.MemberReferences)
    {
        var m = md.GetMemberReference(h);
        if (m.Parent.Kind != HandleKind.TypeReference) continue;
        var s = Scope(m.Parent);
        if (!s.StartsWith("Microsoft.DirectX")) continue;
        var name = md.GetString(m.Name);
        string desc;
        if (m.GetKind() == MemberReferenceKind.Field)
            desc = sig ? $"field {m.DecodeFieldSignature(prov, null)} {name}" : $"field {name}";
        else if (sig)
        {
            var ms = m.DecodeMethodSignature(prov, null);
            desc = $"method {(ms.Header.IsInstance ? "" : "static ")}{ms.ReturnType} {name}({string.Join(", ", ms.ParameterTypes)})";
        }
        else desc = $"method {name}";
        lines.Add($"{s} | {TypeName((TypeReferenceHandle)m.Parent)} | {desc}");
    }
}
foreach (var l in lines) Console.WriteLine(l);

void Defs(IEnumerable<string> paths)
{
    var outl = new SortedSet<string>();
    foreach (var path in paths)
    {
        using var pe = new PEReader(File.OpenRead(path));
        var md = pe.GetMetadataReader();
        var asm = md.GetString(md.GetAssemblyDefinition().Name);
        string RefName(TypeReferenceHandle h)
        {
            var t = md.GetTypeReference(h);
            var outer = t.ResolutionScope.Kind == HandleKind.TypeReference ? RefName((TypeReferenceHandle)t.ResolutionScope) + "+" : md.GetString(t.Namespace) + ".";
            return outer + md.GetString(t.Name);
        }
        string DefName(TypeDefinitionHandle h)
        {
            var t = md.GetTypeDefinition(h);
            var decl = t.GetDeclaringType();
            return (decl.IsNil ? md.GetString(t.Namespace) + "." : DefName(decl) + "+") + md.GetString(t.Name);
        }
        var prov = new Prov(md, RefName, DefName);
        foreach (var th in md.TypeDefinitions)
        {
            var td = md.GetTypeDefinition(th);
            var tn = DefName(th);
            if (tn.StartsWith(".<")) continue;
            outl.Add($"{asm} | {tn} | (type)");
            foreach (var fh in td.GetFields())
            {
                var f = md.GetFieldDefinition(fh);
                outl.Add($"{asm} | {tn} | field {f.DecodeSignature(prov, null)} {md.GetString(f.Name)}");
            }
            foreach (var mh in td.GetMethods())
            {
                var m = md.GetMethodDefinition(mh);
                var ms = m.DecodeSignature(prov, null);
                outl.Add($"{asm} | {tn} | method {(ms.Header.IsInstance ? "" : "static ")}{ms.ReturnType} {md.GetString(m.Name)}({string.Join(", ", ms.ParameterTypes)})");
            }
        }
    }
    foreach (var l in outl) Console.WriteLine(l);
}

sealed class Prov(MetadataReader md, Func<TypeReferenceHandle, string> refName, Func<TypeDefinitionHandle, string>? defName = null) : ISignatureTypeProvider<string, object?>
{
    public string GetPrimitiveType(PrimitiveTypeCode c) => c switch { PrimitiveTypeCode.Object => "System.Object", PrimitiveTypeCode.String => "System.String", _ => c.ToString() };
    public string GetTypeFromDefinition(MetadataReader r, TypeDefinitionHandle h, byte k) => defName != null ? defName(h) : md.GetString(md.GetTypeDefinition(h).Name);
    public string GetTypeFromReference(MetadataReader r, TypeReferenceHandle h, byte k) => refName(h);
    public string GetTypeFromSpecification(MetadataReader r, object? c, TypeSpecificationHandle h, byte k) => "typespec";
    public string GetSZArrayType(string e) => e + "[]";
    public string GetArrayType(string e, ArrayShape s) => e + "[" + new string(',', s.Rank - 1) + "]";
    public string GetByReferenceType(string e) => "ref " + e;
    public string GetPointerType(string e) => e + "*";
    public string GetGenericInstantiation(string g, ImmutableArray<string> a) => g + "<" + string.Join(",", a) + ">";
    public string GetGenericTypeParameter(object? c, int i) => "!" + i;
    public string GetGenericMethodParameter(object? c, int i) => "!!" + i;
    public string GetFunctionPointerType(MethodSignature<string> s) => "fnptr";
    public string GetModifiedType(string m, string u, bool req) => u + (req ? " modreq(" : " modopt(") + m + ")";
    public string GetPinnedType(string e) => e;
}
