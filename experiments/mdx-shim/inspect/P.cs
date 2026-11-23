using System; using System.IO; using System.Linq; using System.Reflection;
class P{static void Main(string[] a){
 var paths=Directory.GetFiles(Path.GetDirectoryName(typeof(object).Assembly.Location),"*.dll").Concat(a.Skip(1));
 using var mlc=new MetadataLoadContext(new PathAssemblyResolver(paths));
 var asm=mlc.LoadFromAssemblyPath(a[1]); Console.WriteLine(asm.FullName);
 Type[] ts; try{ts=asm.GetTypes();}catch(ReflectionTypeLoadException e){ts=e.Types.Where(t=>t!=null).ToArray();}
 Console.WriteLine("public types: "+ts.Count(t=>t.IsPublic));
 foreach(var n in a[0].Split(',')){var t=ts.FirstOrDefault(x=>x.Name==n); Console.WriteLine(n+": "+(t==null?"MISSING":t.GetMembers().Length+" members"));}
}}
