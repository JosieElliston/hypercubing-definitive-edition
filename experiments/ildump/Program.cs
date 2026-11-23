// Minimal IL disassembler: prints the IL of every method whose body references a member
// matching <regex> (matched against "Type::Member" of call/newobj/ldfld/... operands).
// usage: ildump <exe> <regex>      e.g. ildump m3dht633.exe 'Direct3D'
using System.Reflection.Emit;
using System.Reflection.Metadata;
using System.Reflection.Metadata.Ecma335;
using System.Reflection.PortableExecutable;
using System.Text.RegularExpressions;

var pe = new PEReader(File.OpenRead(args[0]));
var md = pe.GetMetadataReader();
var rx = new Regex(args.Length > 1 ? args[1] : ".");
var one = new Dictionary<short, OpCode>(); var two = new Dictionary<short, OpCode>();
foreach (var f in typeof(OpCodes).GetFields()) { var o = (OpCode)f.GetValue(null); if (o.Size == 1) one[o.Value] = o; else two[(short)(o.Value & 0xff)] = o; }

string TypeRefName(EntityHandle h) => h.Kind switch {
    HandleKind.TypeReference => md.GetString(md.GetTypeReference((TypeReferenceHandle)h).Name),
    HandleKind.TypeDefinition => md.GetString(md.GetTypeDefinition((TypeDefinitionHandle)h).Name),
    HandleKind.TypeSpecification => "typespec",
    _ => h.Kind.ToString() };
string Tok(int tok) {
    var h = MetadataTokens.EntityHandle(tok);
    switch (h.Kind) {
        case HandleKind.MemberReference: { var m = md.GetMemberReference((MemberReferenceHandle)h); return TypeRefName(m.Parent) + "::" + md.GetString(m.Name); }
        case HandleKind.MethodDefinition: { var m = md.GetMethodDefinition((MethodDefinitionHandle)h); return TypeRefName(m.GetDeclaringType()) + "::" + md.GetString(m.Name); }
        case HandleKind.FieldDefinition: { var f = md.GetFieldDefinition((FieldDefinitionHandle)h); return TypeRefName(f.GetDeclaringType()) + "::" + md.GetString(f.Name); }
        case HandleKind.MethodSpecification: { var s = md.GetMethodSpecification((MethodSpecificationHandle)h); return Tok(MetadataTokens.GetToken(s.Method)) + "<>"; }
        default: return TypeRefName(h);
    }
}
foreach (var th in md.TypeDefinitions) {
    var td = md.GetTypeDefinition(th);
    foreach (var mh in td.GetMethods()) {
        var mdef = md.GetMethodDefinition(mh);
        if (mdef.RelativeVirtualAddress == 0) continue;
        var body = pe.GetMethodBody(mdef.RelativeVirtualAddress);
        var il = body.GetILBytes();
        var outl = new List<string>(); bool hit = false; int i = 0;
        while (i < il.Length) {
            int at = i; OpCode op;
            if (il[i] == 0xfe) { op = two[il[i + 1]]; i += 2; } else { op = one[il[i]]; i++; }
            string arg = "";
            switch (op.OperandType) {
                case OperandType.InlineNone: break;
                case OperandType.ShortInlineBrTarget: arg = "IL_" + (i + 1 + (sbyte)il[i]).ToString("x4"); i += 1; break;
                case OperandType.ShortInlineI: case OperandType.ShortInlineVar: arg = ((sbyte)il[i]).ToString(); i += 1; break;
                case OperandType.InlineVar: arg = BitConverter.ToInt16(il, i).ToString(); i += 2; break;
                case OperandType.InlineBrTarget: arg = "IL_" + (i + 4 + BitConverter.ToInt32(il, i)).ToString("x4"); i += 4; break;
                case OperandType.InlineI: arg = BitConverter.ToInt32(il, i).ToString(); i += 4; break;
                case OperandType.InlineI8: arg = BitConverter.ToInt64(il, i).ToString(); i += 8; break;
                case OperandType.ShortInlineR: arg = BitConverter.ToSingle(il, i).ToString(); i += 4; break;
                case OperandType.InlineR: arg = BitConverter.ToDouble(il, i).ToString(); i += 8; break;
                case OperandType.InlineString: arg = "\"" + md.GetUserString(MetadataTokens.UserStringHandle(BitConverter.ToInt32(il, i) & 0xffffff)) + "\""; i += 4; break;
                case OperandType.InlineSwitch: { int n = BitConverter.ToInt32(il, i); i += 4 + 4 * n; arg = $"({n} targets)"; break; }
                case OperandType.InlineSig: arg = "sig"; i += 4; break;
                default: arg = Tok(BitConverter.ToInt32(il, i)); i += 4; if (rx.IsMatch(arg)) hit = true; break;
            }
            outl.Add($"  IL_{at:x4}: {op.Name} {arg}");
        }
        if (hit) { Console.WriteLine($"== {md.GetString(td.Name)}::{md.GetString(mdef.Name)}"); foreach (var l in outl) Console.WriteLine(l); }
    }
}
