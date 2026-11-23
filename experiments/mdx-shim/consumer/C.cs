using System; using Microsoft.DirectX;
class C { static void Main() { var v = new Vector3(3, 4, 0); Console.WriteLine("Length=" + v.Length());
  var a = typeof(Vector3).Assembly; Console.WriteLine(a.FullName + " @ " + a.Location); } }
