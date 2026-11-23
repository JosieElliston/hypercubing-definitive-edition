// Microsoft.DirectX math types (Vector3, Matrix, Quaternion) with Managed DirectX 1.1 semantics.
//
// Conventions match D3DX: row vectors (v * M), left-handed, row-major storage with M41..M43
// holding the translation. Formulas follow Wine's d3dx9 math.c. Adapted from the MC7D-KB
// sharpdx-port branch (s3d/MdxMath.cs), where they were cross-checked against SharpDX.
//
// Members past what the four hypercubing programs reference are included only when they are
// one-liners next to ones that are referenced.

using System;
using System.Reflection;
using System.Runtime.InteropServices;

namespace Microsoft.DirectX {

	[StructLayout(LayoutKind.Sequential)]
	public struct Vector3 {
		public float X, Y, Z;

		public Vector3() { X = Y = Z = 0; }
		public Vector3(float valueX, float valueY, float valueZ) { X = valueX; Y = valueY; Z = valueZ; }

		public static Vector3 Empty { get { return new Vector3(0, 0, 0); } }

		public float Length() { return (float)Math.Sqrt(X * X + Y * Y + Z * Z); }
		public static float Length(Vector3 source) { return source.Length(); }
		public float LengthSq() { return X * X + Y * Y + Z * Z; }
		public static float LengthSq(Vector3 source) { return source.LengthSq(); }

		public void Add(Vector3 source) { X += source.X; Y += source.Y; Z += source.Z; }
		public void Subtract(Vector3 source) { X -= source.X; Y -= source.Y; Z -= source.Z; }
		public void Multiply(float s) { X *= s; Y *= s; Z *= s; }
		public void Scale(float scalingFactor) { X *= scalingFactor; Y *= scalingFactor; Z *= scalingFactor; }

		// D3DXVec3Normalize: a zero vector stays zero.
		public void Normalize() {
			float l = Length();
			if (l != 0) { X /= l; Y /= l; Z /= l; } else { X = Y = Z = 0; }
		}

		public static Vector3 Add(Vector3 left, Vector3 right) { return new Vector3(left.X + right.X, left.Y + right.Y, left.Z + right.Z); }
		public static Vector3 Subtract(Vector3 left, Vector3 right) { return new Vector3(left.X - right.X, left.Y - right.Y, left.Z - right.Z); }
		public static Vector3 Multiply(Vector3 source, float f) { return new Vector3(source.X * f, source.Y * f, source.Z * f); }
		public static Vector3 Scale(Vector3 source, float scalingFactor) { return Multiply(source, scalingFactor); }
		public static Vector3 Normalize(Vector3 source) { source.Normalize(); return source; }
		public static Vector3 Lerp(Vector3 left, Vector3 right, float interpolater) { return left + (right - left) * interpolater; }
		public static Vector3 Minimize(Vector3 l, Vector3 r) { return new Vector3(Math.Min(l.X, r.X), Math.Min(l.Y, r.Y), Math.Min(l.Z, r.Z)); }
		public static Vector3 Maximize(Vector3 l, Vector3 r) { return new Vector3(Math.Max(l.X, r.X), Math.Max(l.Y, r.Y), Math.Max(l.Z, r.Z)); }

		public static float Dot(Vector3 left, Vector3 right) { return left.X * right.X + left.Y * right.Y + left.Z * right.Z; }

		public static Vector3 Cross(Vector3 left, Vector3 right) {
			return new Vector3(
				left.Y * right.Z - left.Z * right.Y,
				left.Z * right.X - left.X * right.Z,
				left.X * right.Y - left.Y * right.X);
		}

		// D3DXVec3TransformCoord: treat v as (x, y, z, 1), multiply, divide by w.
		public static Vector3 TransformCoordinate(Vector3 source, Matrix m) {
			float w = source.X * m.M14 + source.Y * m.M24 + source.Z * m.M34 + m.M44;
			if (w == 0) w = 1;
			return new Vector3(
				(source.X * m.M11 + source.Y * m.M21 + source.Z * m.M31 + m.M41) / w,
				(source.X * m.M12 + source.Y * m.M22 + source.Z * m.M32 + m.M42) / w,
				(source.X * m.M13 + source.Y * m.M23 + source.Z * m.M33 + m.M43) / w);
		}
		public void TransformCoordinate(Matrix sourceMatrix) { this = TransformCoordinate(this, sourceMatrix); }

		// D3DXVec3TransformNormal: (x, y, z, 0).
		public static Vector3 TransformNormal(Vector3 source, Matrix m) {
			return new Vector3(
				source.X * m.M11 + source.Y * m.M21 + source.Z * m.M31,
				source.X * m.M12 + source.Y * m.M22 + source.Z * m.M32,
				source.X * m.M13 + source.Y * m.M23 + source.Z * m.M33);
		}
		public void TransformNormal(Matrix sourceMatrix) { this = TransformNormal(this, sourceMatrix); }

		// D3DXVec3Project. The viewport is a boxed Microsoft.DirectX.Direct3D.Viewport, which this
		// assembly can't name (Direct3D references this one), so read its fields by reflection.
		public static Vector3 Project(Vector3 v, object viewport, Matrix projection, Matrix view, Matrix world) {
			float vx, vy, vw, vh, minZ, maxZ;
			ReadViewport(viewport, out vx, out vy, out vw, out vh, out minZ, out maxZ);
			Vector3 p = TransformCoordinate(v, world * view * projection);
			return new Vector3(
				vx + (1.0f + p.X) * vw / 2.0f,
				vy + (1.0f - p.Y) * vh / 2.0f,
				minZ + p.Z * (maxZ - minZ));
		}
		public void Project(object viewport, Matrix projection, Matrix view, Matrix world) { this = Project(this, viewport, projection, view, world); }

		// D3DXVec3Unproject.
		public static Vector3 Unproject(Vector3 v, object viewport, Matrix projection, Matrix view, Matrix world) {
			float vx, vy, vw, vh, minZ, maxZ;
			ReadViewport(viewport, out vx, out vy, out vw, out vh, out minZ, out maxZ);
			Matrix m = Matrix.Invert(world * view * projection);
			Vector3 p = new Vector3(
				2.0f * (v.X - vx) / vw - 1.0f,
				1.0f - 2.0f * (v.Y - vy) / vh,
				(v.Z - minZ) / (maxZ - minZ));
			return TransformCoordinate(p, m);
		}
		public void Unproject(object viewport, Matrix projection, Matrix view, Matrix world) { this = Unproject(this, viewport, projection, view, world); }

		static void ReadViewport(object vp, out float x, out float y, out float w, out float h, out float minZ, out float maxZ) {
			Type t = vp.GetType();
			x = Convert.ToSingle(Prop(t, vp, "X")); y = Convert.ToSingle(Prop(t, vp, "Y"));
			w = Convert.ToSingle(Prop(t, vp, "Width")); h = Convert.ToSingle(Prop(t, vp, "Height"));
			minZ = Convert.ToSingle(Prop(t, vp, "MinZ")); maxZ = Convert.ToSingle(Prop(t, vp, "MaxZ"));
		}
		static object Prop(Type t, object o, string name) { return t.GetProperty(name, BindingFlags.Public | BindingFlags.Instance).GetValue(o, null); }

		public static Vector3 operator +(Vector3 left, Vector3 right) { return Add(left, right); }
		public static Vector3 operator -(Vector3 left, Vector3 right) { return Subtract(left, right); }
		public static Vector3 operator -(Vector3 vec) { return new Vector3(-vec.X, -vec.Y, -vec.Z); }
		public static Vector3 operator *(Vector3 left, float right) { return Multiply(left, right); }
		public static Vector3 operator *(float left, Vector3 right) { return Multiply(right, left); }
		public static bool operator ==(Vector3 left, Vector3 right) { return left.X == right.X && left.Y == right.Y && left.Z == right.Z; }
		public static bool operator !=(Vector3 left, Vector3 right) { return !(left == right); }
		public override bool Equals(object compare) { return compare is Vector3 && this == (Vector3)compare; }
		public override int GetHashCode() { return X.GetHashCode() ^ Y.GetHashCode() ^ Z.GetHashCode(); }
		public override string ToString() { return "X: " + X + "\nY: " + Y + "\nZ: " + Z + "\n"; }
	}

	[StructLayout(LayoutKind.Sequential)]
	public struct Quaternion {
		public float X, Y, Z, W;

		public Quaternion() { X = Y = Z = W = 0; }
		public Quaternion(float valueX, float valueY, float valueZ, float valueW) { X = valueX; Y = valueY; Z = valueZ; W = valueW; }

		public static Quaternion Identity { get { return new Quaternion(0, 0, 0, 1); } }

		// D3DXQuaternionRotationAxis.
		public static Quaternion RotationAxis(Vector3 v, float angle) {
			Vector3 n = Vector3.Normalize(v);
			float s = (float)Math.Sin(angle / 2.0f);
			return new Quaternion(s * n.X, s * n.Y, s * n.Z, (float)Math.Cos(angle / 2.0f));
		}

		// D3DXQuaternionRotationMatrix (Wine's implementation).
		public static Quaternion RotationMatrix(Matrix m) {
			Quaternion q;
			float s;
			float trace = m.M11 + m.M22 + m.M33 + 1.0f;
			if (trace > 1.0f) {
				s = 2.0f * (float)Math.Sqrt(trace);
				q.X = (m.M23 - m.M32) / s;
				q.Y = (m.M31 - m.M13) / s;
				q.Z = (m.M12 - m.M21) / s;
				q.W = 0.25f * s;
				return q;
			}
			int maxi = 0;
			if (m.M22 > m.M11) maxi = 1;
			if (m.M33 > (maxi == 0 ? m.M11 : m.M22)) maxi = 2;
			switch (maxi) {
				case 0:
					s = 2.0f * (float)Math.Sqrt(1.0f + m.M11 - m.M22 - m.M33);
					q.X = 0.25f * s;
					q.Y = (m.M12 + m.M21) / s;
					q.Z = (m.M13 + m.M31) / s;
					q.W = (m.M23 - m.M32) / s;
					break;
				case 1:
					s = 2.0f * (float)Math.Sqrt(1.0f + m.M22 - m.M11 - m.M33);
					q.X = (m.M12 + m.M21) / s;
					q.Y = 0.25f * s;
					q.Z = (m.M23 + m.M32) / s;
					q.W = (m.M31 - m.M13) / s;
					break;
				default:
					s = 2.0f * (float)Math.Sqrt(1.0f + m.M33 - m.M11 - m.M22);
					q.X = (m.M13 + m.M31) / s;
					q.Y = (m.M23 + m.M32) / s;
					q.Z = 0.25f * s;
					q.W = (m.M12 - m.M21) / s;
					break;
			}
			return q;
		}

		public static bool operator ==(Quaternion l, Quaternion r) { return l.X == r.X && l.Y == r.Y && l.Z == r.Z && l.W == r.W; }
		public static bool operator !=(Quaternion l, Quaternion r) { return !(l == r); }
		public override bool Equals(object o) { return o is Quaternion && this == (Quaternion)o; }
		public override int GetHashCode() { return X.GetHashCode() ^ Y.GetHashCode() ^ Z.GetHashCode() ^ W.GetHashCode(); }
		public override string ToString() { return "X: " + X + "\nY: " + Y + "\nZ: " + Z + "\nW: " + W + "\n"; }
	}

	[StructLayout(LayoutKind.Sequential)]
	public struct Matrix {
		public float M11, M12, M13, M14;
		public float M21, M22, M23, M24;
		public float M31, M32, M33, M34;
		public float M41, M42, M43, M44;

		public Matrix() { this = default(Matrix); }

		public static Matrix Identity {
			get {
				Matrix m = default(Matrix);
				m.M11 = m.M22 = m.M33 = m.M44 = 1;
				return m;
			}
		}

		public static Matrix Zero { get { return default(Matrix); } }

		public static Matrix Multiply(Matrix a, Matrix b) {
			Matrix r;
			r.M11 = a.M11 * b.M11 + a.M12 * b.M21 + a.M13 * b.M31 + a.M14 * b.M41;
			r.M12 = a.M11 * b.M12 + a.M12 * b.M22 + a.M13 * b.M32 + a.M14 * b.M42;
			r.M13 = a.M11 * b.M13 + a.M12 * b.M23 + a.M13 * b.M33 + a.M14 * b.M43;
			r.M14 = a.M11 * b.M14 + a.M12 * b.M24 + a.M13 * b.M34 + a.M14 * b.M44;
			r.M21 = a.M21 * b.M11 + a.M22 * b.M21 + a.M23 * b.M31 + a.M24 * b.M41;
			r.M22 = a.M21 * b.M12 + a.M22 * b.M22 + a.M23 * b.M32 + a.M24 * b.M42;
			r.M23 = a.M21 * b.M13 + a.M22 * b.M23 + a.M23 * b.M33 + a.M24 * b.M43;
			r.M24 = a.M21 * b.M14 + a.M22 * b.M24 + a.M23 * b.M34 + a.M24 * b.M44;
			r.M31 = a.M31 * b.M11 + a.M32 * b.M21 + a.M33 * b.M31 + a.M34 * b.M41;
			r.M32 = a.M31 * b.M12 + a.M32 * b.M22 + a.M33 * b.M32 + a.M34 * b.M42;
			r.M33 = a.M31 * b.M13 + a.M32 * b.M23 + a.M33 * b.M33 + a.M34 * b.M43;
			r.M34 = a.M31 * b.M14 + a.M32 * b.M24 + a.M33 * b.M34 + a.M34 * b.M44;
			r.M41 = a.M41 * b.M11 + a.M42 * b.M21 + a.M43 * b.M31 + a.M44 * b.M41;
			r.M42 = a.M41 * b.M12 + a.M42 * b.M22 + a.M43 * b.M32 + a.M44 * b.M42;
			r.M43 = a.M41 * b.M13 + a.M42 * b.M23 + a.M43 * b.M33 + a.M44 * b.M43;
			r.M44 = a.M41 * b.M14 + a.M42 * b.M24 + a.M43 * b.M34 + a.M44 * b.M44;
			return r;
		}
		public void Multiply(Matrix source) { this = Multiply(this, source); }

		public static Matrix operator *(Matrix left, Matrix right) { return Multiply(left, right); }

		public static Matrix Translation(float x, float y, float z) {
			Matrix m = Identity;
			m.M41 = x; m.M42 = y; m.M43 = z;
			return m;
		}
		public static Matrix Translation(Vector3 v) { return Translation(v.X, v.Y, v.Z); }

		public static Matrix Scaling(float x, float y, float z) {
			Matrix m = Identity;
			m.M11 = x; m.M22 = y; m.M33 = z;
			return m;
		}
		public static Matrix Scaling(Vector3 v) { return Scaling(v.X, v.Y, v.Z); }

		public static Matrix RotationX(float angle) {
			float c = (float)Math.Cos(angle), s = (float)Math.Sin(angle);
			Matrix m = Identity;
			m.M22 = c; m.M23 = s; m.M32 = -s; m.M33 = c;
			return m;
		}

		public static Matrix RotationY(float angle) {
			float c = (float)Math.Cos(angle), s = (float)Math.Sin(angle);
			Matrix m = Identity;
			m.M11 = c; m.M13 = -s; m.M31 = s; m.M33 = c;
			return m;
		}

		public static Matrix RotationZ(float angle) {
			float c = (float)Math.Cos(angle), s = (float)Math.Sin(angle);
			Matrix m = Identity;
			m.M11 = c; m.M12 = s; m.M21 = -s; m.M22 = c;
			return m;
		}

		// D3DXMatrixRotationAxis: the axis is normalized first.
		public static Matrix RotationAxis(Vector3 axisRotation, float angle) {
			Vector3 v = Vector3.Normalize(axisRotation);
			float c = (float)Math.Cos(angle), s = (float)Math.Sin(angle), t = 1.0f - c;
			Matrix m = Identity;
			m.M11 = t * v.X * v.X + c;
			m.M21 = t * v.X * v.Y - s * v.Z;
			m.M31 = t * v.X * v.Z + s * v.Y;
			m.M12 = t * v.Y * v.X + s * v.Z;
			m.M22 = t * v.Y * v.Y + c;
			m.M32 = t * v.Y * v.Z - s * v.X;
			m.M13 = t * v.Z * v.X - s * v.Y;
			m.M23 = t * v.Z * v.Y + s * v.X;
			m.M33 = t * v.Z * v.Z + c;
			return m;
		}

		// D3DXMatrixRotationQuaternion.
		public static Matrix RotationQuaternion(Quaternion q) {
			Matrix m = Identity;
			m.M11 = 1.0f - 2.0f * (q.Y * q.Y + q.Z * q.Z);
			m.M12 = 2.0f * (q.X * q.Y + q.Z * q.W);
			m.M13 = 2.0f * (q.X * q.Z - q.Y * q.W);
			m.M21 = 2.0f * (q.X * q.Y - q.Z * q.W);
			m.M22 = 1.0f - 2.0f * (q.X * q.X + q.Z * q.Z);
			m.M23 = 2.0f * (q.Y * q.Z + q.X * q.W);
			m.M31 = 2.0f * (q.X * q.Z + q.Y * q.W);
			m.M32 = 2.0f * (q.Y * q.Z - q.X * q.W);
			m.M33 = 1.0f - 2.0f * (q.X * q.X + q.Y * q.Y);
			return m;
		}

		// D3DXMatrixLookAtLH.
		public static Matrix LookAtLH(Vector3 cameraPosition, Vector3 cameraTarget, Vector3 cameraUpVector) {
			Vector3 z = Vector3.Normalize(cameraTarget - cameraPosition);
			Vector3 x = Vector3.Normalize(Vector3.Cross(cameraUpVector, z));
			Vector3 y = Vector3.Cross(z, x);
			Matrix m = Identity;
			m.M11 = x.X; m.M12 = y.X; m.M13 = z.X;
			m.M21 = x.Y; m.M22 = y.Y; m.M23 = z.Y;
			m.M31 = x.Z; m.M32 = y.Z; m.M33 = z.Z;
			m.M41 = -Vector3.Dot(x, cameraPosition);
			m.M42 = -Vector3.Dot(y, cameraPosition);
			m.M43 = -Vector3.Dot(z, cameraPosition);
			return m;
		}

		// D3DXMatrixPerspectiveFovLH.
		public static Matrix PerspectiveFovLH(float fieldOfViewY, float aspectRatio, float znearPlane, float zfarPlane) {
			float ys = 1.0f / (float)Math.Tan(fieldOfViewY / 2.0f);
			Matrix m = default(Matrix);
			m.M11 = ys / aspectRatio;
			m.M22 = ys;
			m.M33 = zfarPlane / (zfarPlane - znearPlane);
			m.M34 = 1.0f;
			m.M43 = -znearPlane * zfarPlane / (zfarPlane - znearPlane);
			return m;
		}

		// D3DXMatrixOrthoLH.
		public static Matrix OrthoLH(float width, float height, float znearPlane, float zfarPlane) {
			Matrix m = Identity;
			m.M11 = 2.0f / width;
			m.M22 = 2.0f / height;
			m.M33 = 1.0f / (zfarPlane - znearPlane);
			m.M43 = znearPlane / (znearPlane - zfarPlane);
			return m;
		}

		public float Determinant {
			get {
				float det;
				InvertCore(out det, this);
				return det;
			}
		}

		// General 4x4 inverse via cofactors, computed in double precision.
		static Matrix InvertCore(out float determinant, Matrix m) {
			double[] a = {
				m.M11, m.M12, m.M13, m.M14, m.M21, m.M22, m.M23, m.M24,
				m.M31, m.M32, m.M33, m.M34, m.M41, m.M42, m.M43, m.M44 };
			double[] inv = new double[16];
			inv[0] = a[5]*a[10]*a[15] - a[5]*a[11]*a[14] - a[9]*a[6]*a[15] + a[9]*a[7]*a[14] + a[13]*a[6]*a[11] - a[13]*a[7]*a[10];
			inv[4] = -a[4]*a[10]*a[15] + a[4]*a[11]*a[14] + a[8]*a[6]*a[15] - a[8]*a[7]*a[14] - a[12]*a[6]*a[11] + a[12]*a[7]*a[10];
			inv[8] = a[4]*a[9]*a[15] - a[4]*a[11]*a[13] - a[8]*a[5]*a[15] + a[8]*a[7]*a[13] + a[12]*a[5]*a[11] - a[12]*a[7]*a[9];
			inv[12] = -a[4]*a[9]*a[14] + a[4]*a[10]*a[13] + a[8]*a[5]*a[14] - a[8]*a[6]*a[13] - a[12]*a[5]*a[10] + a[12]*a[6]*a[9];
			inv[1] = -a[1]*a[10]*a[15] + a[1]*a[11]*a[14] + a[9]*a[2]*a[15] - a[9]*a[3]*a[14] - a[13]*a[2]*a[11] + a[13]*a[3]*a[10];
			inv[5] = a[0]*a[10]*a[15] - a[0]*a[11]*a[14] - a[8]*a[2]*a[15] + a[8]*a[3]*a[14] + a[12]*a[2]*a[11] - a[12]*a[3]*a[10];
			inv[9] = -a[0]*a[9]*a[15] + a[0]*a[11]*a[13] + a[8]*a[1]*a[15] - a[8]*a[3]*a[13] - a[12]*a[1]*a[11] + a[12]*a[3]*a[9];
			inv[13] = a[0]*a[9]*a[14] - a[0]*a[10]*a[13] - a[8]*a[1]*a[14] + a[8]*a[2]*a[13] + a[12]*a[1]*a[10] - a[12]*a[2]*a[9];
			inv[2] = a[1]*a[6]*a[15] - a[1]*a[7]*a[14] - a[5]*a[2]*a[15] + a[5]*a[3]*a[14] + a[13]*a[2]*a[7] - a[13]*a[3]*a[6];
			inv[6] = -a[0]*a[6]*a[15] + a[0]*a[7]*a[14] + a[4]*a[2]*a[15] - a[4]*a[3]*a[14] - a[12]*a[2]*a[7] + a[12]*a[3]*a[6];
			inv[10] = a[0]*a[5]*a[15] - a[0]*a[7]*a[13] - a[4]*a[1]*a[15] + a[4]*a[3]*a[13] + a[12]*a[1]*a[7] - a[12]*a[3]*a[5];
			inv[14] = -a[0]*a[5]*a[14] + a[0]*a[6]*a[13] + a[4]*a[1]*a[14] - a[4]*a[2]*a[13] - a[12]*a[1]*a[6] + a[12]*a[2]*a[5];
			inv[3] = -a[1]*a[6]*a[11] + a[1]*a[7]*a[10] + a[5]*a[2]*a[11] - a[5]*a[3]*a[10] - a[9]*a[2]*a[7] + a[9]*a[3]*a[6];
			inv[7] = a[0]*a[6]*a[11] - a[0]*a[7]*a[10] - a[4]*a[2]*a[11] + a[4]*a[3]*a[10] + a[8]*a[2]*a[7] - a[8]*a[3]*a[6];
			inv[11] = -a[0]*a[5]*a[11] + a[0]*a[7]*a[9] + a[4]*a[1]*a[11] - a[4]*a[3]*a[9] - a[8]*a[1]*a[7] + a[8]*a[3]*a[5];
			inv[15] = a[0]*a[5]*a[10] - a[0]*a[6]*a[9] - a[4]*a[1]*a[10] + a[4]*a[2]*a[9] + a[8]*a[1]*a[6] - a[8]*a[2]*a[5];
			double det = a[0]*inv[0] + a[1]*inv[4] + a[2]*inv[8] + a[3]*inv[12];
			determinant = (float)det;
			if (det == 0)
				return m; // singular: D3DX returns NULL here; none of the programs hit it
			double r = 1.0 / det;
			Matrix o;
			o.M11 = (float)(inv[0]*r);  o.M12 = (float)(inv[1]*r);  o.M13 = (float)(inv[2]*r);  o.M14 = (float)(inv[3]*r);
			o.M21 = (float)(inv[4]*r);  o.M22 = (float)(inv[5]*r);  o.M23 = (float)(inv[6]*r);  o.M24 = (float)(inv[7]*r);
			o.M31 = (float)(inv[8]*r);  o.M32 = (float)(inv[9]*r);  o.M33 = (float)(inv[10]*r); o.M34 = (float)(inv[11]*r);
			o.M41 = (float)(inv[12]*r); o.M42 = (float)(inv[13]*r); o.M43 = (float)(inv[14]*r); o.M44 = (float)(inv[15]*r);
			return o;
		}

		public static Matrix Invert(ref float determinant, Matrix source) { return InvertCore(out determinant, source); }
		public static Matrix Invert(Matrix source) { float det; return InvertCore(out det, source); }
		public void Invert() { this = Invert(this); }

		public static Matrix TransposeMatrix(Matrix s) {
			Matrix m;
			m.M11 = s.M11; m.M12 = s.M21; m.M13 = s.M31; m.M14 = s.M41;
			m.M21 = s.M12; m.M22 = s.M22; m.M23 = s.M32; m.M24 = s.M42;
			m.M31 = s.M13; m.M32 = s.M23; m.M33 = s.M33; m.M34 = s.M43;
			m.M41 = s.M14; m.M42 = s.M24; m.M43 = s.M34; m.M44 = s.M44;
			return m;
		}

		public static bool operator ==(Matrix l, Matrix r) {
			return l.M11 == r.M11 && l.M12 == r.M12 && l.M13 == r.M13 && l.M14 == r.M14 &&
				l.M21 == r.M21 && l.M22 == r.M22 && l.M23 == r.M23 && l.M24 == r.M24 &&
				l.M31 == r.M31 && l.M32 == r.M32 && l.M33 == r.M33 && l.M34 == r.M34 &&
				l.M41 == r.M41 && l.M42 == r.M42 && l.M43 == r.M43 && l.M44 == r.M44;
		}
		public static bool operator !=(Matrix l, Matrix r) { return !(l == r); }
		public override bool Equals(object o) { return o is Matrix && this == (Matrix)o; }
		public override int GetHashCode() { return M11.GetHashCode() ^ M22.GetHashCode() ^ M33.GetHashCode() ^ M41.GetHashCode() ^ M42.GetHashCode() ^ M43.GetHashCode(); }
	}

	// Base of every exception Managed DirectX throws.
	[Serializable]
	public class DirectXException : ApplicationException {
		int m_errorCode;
		public static bool IsExceptionIgnored;

		public DirectXException() { }
		public DirectXException(string message) : base(message) { }
		public DirectXException(string message, Exception inner) : base(message, inner) { }
		protected DirectXException(System.Runtime.Serialization.SerializationInfo info, System.Runtime.Serialization.StreamingContext context) : base(info, context) { }

		public int ErrorCode { get { return m_errorCode; } set { m_errorCode = value; } }
		public string ErrorString { get { return GetDirectXErrorString(m_errorCode); } }
		public static string GetDirectXErrorString(int errorCode) { return "HRESULT 0x" + errorCode.ToString("X8"); }
		public static void IgnoreExceptions() { IsExceptionIgnored = true; }
		public static void EnableExceptions() { IsExceptionIgnored = false; }
	}
}
