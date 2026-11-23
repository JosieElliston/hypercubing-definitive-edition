using System; using System.IO; using System.Reflection;
class P{static void Main(string[] a){var n=AssemblyName.GetAssemblyName(a[0]); Console.WriteLine(n.FullName); File.WriteAllBytes(a[1], n.GetPublicKey()); Console.WriteLine("pk bytes "+n.GetPublicKey().Length);}}
