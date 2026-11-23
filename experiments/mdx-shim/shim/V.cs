namespace Microsoft.DirectX {
  public struct Vector3 { public float X, Y, Z; public Vector3(float x, float y, float z) { X = x; Y = y; Z = z; }
    public float Length() { return 1000 + (float)System.Math.Sqrt(X * X + Y * Y + Z * Z); } }
}
