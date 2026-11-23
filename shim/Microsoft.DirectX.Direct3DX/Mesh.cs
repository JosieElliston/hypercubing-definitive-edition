// BaseMesh and Mesh from Microsoft.DirectX.Direct3DX, without d3dx9: a triangle list in
// managed-pool vertex and index buffers, plus the Box / Cylinder / Sphere builders.
//
// Every face has attribute 0, so DrawSubset(0) draws the whole mesh and other subsets draw
// nothing. That matches meshes from the Mesh constructor (whose attribute buffer starts zeroed)
// and from D3DXCreateBox/Cylinder/Sphere. The shapes follow D3DX's layout (centered at the
// origin; cylinder and sphere axis along Z) but are not vertex-for-vertex identical.
// Builders adapted from the MC7D-KB sharpdx-port branch (s3d/MdxMesh.cs).

using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace Microsoft.DirectX.Direct3D {

	public abstract unsafe class BaseMesh : MarshalByRefObject, IDisposable {
		internal Device m_device;
		internal IntPtr m_vb, m_ib;
		internal int m_numVerts, m_numFaces, m_stride;
		internal bool m_use32;
		internal VertexFormats m_fvf;
		MeshFlags m_options;
		// Byte copies of the buffers, so Lock never reads back from d3d9.
		byte[] m_vdata, m_idata;
		Array m_vlocked, m_ilocked;
		LockFlags m_vflags, m_iflags;

		internal void Init(Device device, int numFaces, int numVerts, MeshFlags options, VertexFormats fvf) {
			m_device = device;
			m_numFaces = numFaces;
			m_numVerts = numVerts;
			m_options = options;
			m_fvf = fvf;
			m_stride = FvfSize(fvf);
			m_use32 = (options & MeshFlags.Use32Bit) != 0;
			const int MANAGED = 1;
			m_vdata = new byte[Math.Max(1, numVerts) * m_stride];
			m_idata = new byte[Math.Max(1, numFaces * 3) * (m_use32 ? 4 : 2)];
			m_vb = Com.CreateVertexBuffer(device.UnmanagedComPointer, m_vdata.Length, 0, (int)fvf, MANAGED);
			m_ib = Com.CreateIndexBuffer(device.UnmanagedComPointer, m_idata.Length, 0, m_use32, MANAGED);
		}

		public Device Device { get { return m_device; } }
		public int NumberVertices { get { return m_numVerts; } }
		public int NumberFaces { get { return m_numFaces; } }
		public VertexFormats VertexFormat { get { return m_fvf; } }
		public MeshFlags Options { get { return m_options; } }
		public int NumberBytesPerVertex { get { return m_stride; } }
		public bool Disposed { get { return m_vb == IntPtr.Zero; } }

		public void DrawSubset(int attributeID) {
			if (attributeID != 0 || m_numFaces == 0 || m_vb == IntPtr.Zero) return;
			IntPtr d = m_device.UnmanagedComPointer;
			Com.Check(((delegate* unmanaged[Stdcall]<IntPtr, uint, int>)Com.Fn(d, Com.DevSetFVF))(d, (uint)m_fvf));
			Com.Check(((delegate* unmanaged[Stdcall]<IntPtr, uint, IntPtr, uint, uint, int>)Com.Fn(d, Com.DevSetStreamSource))(d, 0, m_vb, 0, (uint)m_stride));
			Com.Check(((delegate* unmanaged[Stdcall]<IntPtr, IntPtr, int>)Com.Fn(d, Com.DevSetIndices))(d, m_ib));
			const int TRIANGLELIST = 4;
			Com.Check(((delegate* unmanaged[Stdcall]<IntPtr, int, int, uint, uint, uint, uint, int>)Com.Fn(d, Com.DevDrawIndexedPrimitive))
				(d, TRIANGLELIST, 0, 0, (uint)m_numVerts, 0, (uint)m_numFaces));
		}

		static Array ToTyped(byte[] data, Type type, int[] ranks) {
			int elem = Marshal.SizeOf(type);
			int n = ranks != null && ranks.Length > 0 ? ranks[0] : data.Length / elem;
			Array a = Array.CreateInstance(type, n);
			int bytes = Math.Min(n * elem, data.Length);
			GCHandle h = GCHandle.Alloc(a, GCHandleType.Pinned);
			try { Marshal.Copy(data, 0, h.AddrOfPinnedObject(), bytes); } finally { h.Free(); }
			return a;
		}

		static int FromTyped(Array a, byte[] data) {
			int bytes = Math.Min(a.Length * Marshal.SizeOf(a.GetType().GetElementType()), data.Length);
			GCHandle h = GCHandle.Alloc(a, GCHandleType.Pinned);
			try { Marshal.Copy(h.AddrOfPinnedObject(), data, 0, bytes); } finally { h.Free(); }
			return bytes;
		}

		public Array LockVertexBuffer(Type typeVertex, LockFlags flags, params int[] ranks) {
			m_vflags = flags;
			return m_vlocked = ToTyped(m_vdata, typeVertex, ranks);
		}
		public void UnlockVertexBuffer() {
			if (m_vlocked == null) return;
			Array a = m_vlocked; m_vlocked = null;
			if ((m_vflags & LockFlags.ReadOnly) != 0) return;
			int n = FromTyped(a, m_vdata);
			fixed (byte* p = m_vdata) Com.Upload(m_vb, 0, p, n);
		}

		public Array LockIndexBuffer(Type typeIndex, LockFlags flags, params int[] ranks) {
			m_iflags = flags;
			return m_ilocked = ToTyped(m_idata, typeIndex, ranks);
		}
		public void UnlockIndexBuffer() {
			if (m_ilocked == null) return;
			Array a = m_ilocked; m_ilocked = null;
			if ((m_iflags & LockFlags.ReadOnly) != 0) return;
			int n = FromTyped(a, m_idata);
			fixed (byte* p = m_idata) Com.Upload(m_ib, 0, p, n);
		}

		internal void SetData<T>(T[] vertices, ushort[] indices) where T : struct {
			Array v = LockVertexBuffer(typeof(T), LockFlags.None, vertices.Length);
			Array.Copy(vertices, v, vertices.Length);
			UnlockVertexBuffer();
			Array i = LockIndexBuffer(typeof(ushort), LockFlags.None, indices.Length);
			Array.Copy(indices, i, indices.Length);
			UnlockIndexBuffer();
		}

		public void Dispose() {
			Release();
			GC.SuppressFinalize(this);
		}
		~BaseMesh() { Release(); }
		void Release() {
			IntPtr vb = m_vb, ib = m_ib;
			m_vb = m_ib = IntPtr.Zero;
			Com.Release(vb);
			Com.Release(ib);
		}

		// D3DXGetFVFVertexSize
		internal static int FvfSize(VertexFormats fvf) {
			int f = (int)fvf, size;
			switch (f & 0x400E) {
				case 0x002: size = 12; break;          // XYZ
				case 0x004: case 0x4002: size = 16; break; // XYZRHW, XYZW
				case 0x006: size = 16; break;
				case 0x008: size = 20; break;
				case 0x00A: size = 24; break;
				case 0x00C: size = 28; break;
				case 0x00E: size = 32; break;
				default: size = 0; break;
			}
			if ((f & 0x10) != 0) size += 12; // normal
			if ((f & 0x20) != 0) size += 4;  // point size
			if ((f & 0x40) != 0) size += 4;  // diffuse
			if ((f & 0x80) != 0) size += 4;  // specular
			int tex = (f >> 8) & 0xF;
			for (int i = 0; i < tex; i++) {
				switch ((f >> (16 + i * 2)) & 3) {
					case 0: size += 8; break;
					case 1: size += 12; break;
					case 2: size += 16; break;
					case 3: size += 4; break;
				}
			}
			return size;
		}

		public static bool operator ==(BaseMesh left, BaseMesh right) { return ReferenceEquals(left, right); }
		public static bool operator !=(BaseMesh left, BaseMesh right) { return !ReferenceEquals(left, right); }
		public override bool Equals(object compare) { return ReferenceEquals(this, compare); }
		public override int GetHashCode() { return m_vb.GetHashCode(); }
	}

	public sealed class Mesh : BaseMesh {
		Mesh() { }

		public Mesh(int numFaces, int numVertices, MeshFlags options, VertexFormats vertexFormat, Device device) {
			Init(device, numFaces, numVertices, options, vertexFormat);
		}

		// The programs call Mesh::Dispose, not BaseMesh::Dispose; declare it here so the member
		// reference matches without relying on base-class lookup.
		public new void Dispose() { base.Dispose(); }

		public static bool operator ==(Mesh left, Mesh right) { return ReferenceEquals(left, right); }
		public static bool operator !=(Mesh left, Mesh right) { return !ReferenceEquals(left, right); }
		public override bool Equals(object compare) { return ReferenceEquals(this, compare); }
		public override int GetHashCode() { return base.GetHashCode(); }

		// ---- shape builders (position + normal), as D3DXCreateBox/Cylinder/Sphere ----

		[StructLayout(LayoutKind.Sequential)]
		struct PosNormal {
			public Vector3 P, N;
			public PosNormal(Vector3 p, Vector3 n) { P = p; N = n; }
		}

		sealed class Builder {
			public List<PosNormal> V = new List<PosNormal>();
			public List<ushort> I = new List<ushort>();
			public int Add(Vector3 p, Vector3 n) { V.Add(new PosNormal(p, n)); return V.Count - 1; }
			// D3D's default front face is clockwise on screen, which for a left-handed
			// system means cross(b-a, c-a) points along the outward normal.
			public void Tri(int a, int b, int c) {
				Vector3 pa = V[a].P, pb = V[b].P, pc = V[c].P;
				Vector3 n = V[a].N + V[b].N + V[c].N;
				if (Vector3.Dot(Vector3.Cross(pb - pa, pc - pa), n) < 0) { int t = b; b = c; c = t; }
				I.Add((ushort)a); I.Add((ushort)b); I.Add((ushort)c);
			}
			public Mesh Build(Device d) {
				Mesh m = new Mesh();
				m.Init(d, I.Count / 3, V.Count, MeshFlags.Managed, VertexFormats.Position | VertexFormats.Normal);
				m.SetData(V.ToArray(), I.ToArray());
				return m;
			}
		}

		public static Mesh Box(Device device, float width, float height, float depth) {
			Builder b = new Builder();
			Vector3 h = new Vector3(width / 2, height / 2, depth / 2);
			Vector3[] normals = {
				new Vector3(-1, 0, 0), new Vector3(1, 0, 0),
				new Vector3(0, -1, 0), new Vector3(0, 1, 0),
				new Vector3(0, 0, -1), new Vector3(0, 0, 1) };
			float[,] sgn = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } };
			foreach (Vector3 n in normals) {
				Vector3 u = Math.Abs(n.X) > 0 ? new Vector3(0, 1, 0) : new Vector3(1, 0, 0);
				Vector3 v = Vector3.Cross(n, u);
				int[] q = new int[4];
				for (int k = 0; k < 4; k++) {
					Vector3 p = n + u * sgn[k, 0] + v * sgn[k, 1];
					q[k] = b.Add(new Vector3(p.X * h.X, p.Y * h.Y, p.Z * h.Z), n);
				}
				b.Tri(q[0], q[1], q[2]);
				b.Tri(q[0], q[2], q[3]);
			}
			return b.Build(device);
		}

		public static Mesh Cylinder(Device device, float radius1, float radius2, float length, int slices, int stacks) {
			Builder b = new Builder();
			float z0 = -length / 2;
			float slope = length != 0 ? (radius1 - radius2) / length : 0;
			int[,] ring = new int[stacks + 1, slices + 1];
			for (int s = 0; s <= stacks; s++) {
				float t = (float)s / stacks;
				float r = radius1 + (radius2 - radius1) * t;
				float z = z0 + length * t;
				for (int i = 0; i <= slices; i++) {
					double th = 2 * Math.PI * i / slices;
					float c = (float)Math.Cos(th), sn = (float)Math.Sin(th);
					ring[s, i] = b.Add(new Vector3(r * c, r * sn, z), Vector3.Normalize(new Vector3(c, sn, slope)));
				}
			}
			for (int s = 0; s < stacks; s++)
				for (int i = 0; i < slices; i++) {
					b.Tri(ring[s, i], ring[s, i + 1], ring[s + 1, i + 1]);
					b.Tri(ring[s, i], ring[s + 1, i + 1], ring[s + 1, i]);
				}
			for (int end = 0; end < 2; end++) {
				float r = end == 0 ? radius1 : radius2;
				float z = end == 0 ? z0 : -z0;
				Vector3 n = new Vector3(0, 0, end == 0 ? -1 : 1);
				int center = b.Add(new Vector3(0, 0, z), n);
				int first = b.V.Count;
				for (int i = 0; i <= slices; i++) {
					double th = 2 * Math.PI * i / slices;
					b.Add(new Vector3(r * (float)Math.Cos(th), r * (float)Math.Sin(th), z), n);
				}
				for (int i = 0; i < slices; i++)
					b.Tri(center, first + i, first + i + 1);
			}
			return b.Build(device);
		}

		public static Mesh Sphere(Device device, float radius, int slices, int stacks) {
			Builder b = new Builder();
			int[,] grid = new int[stacks + 1, slices + 1];
			for (int s = 0; s <= stacks; s++) {
				double phi = Math.PI * s / stacks; // 0 at +Z
				for (int i = 0; i <= slices; i++) {
					double th = 2 * Math.PI * i / slices;
					Vector3 n = new Vector3(
						(float)(Math.Sin(phi) * Math.Cos(th)),
						(float)(Math.Sin(phi) * Math.Sin(th)),
						(float)Math.Cos(phi));
					grid[s, i] = b.Add(n * radius, n);
				}
			}
			for (int s = 0; s < stacks; s++)
				for (int i = 0; i < slices; i++) {
					if (s > 0) b.Tri(grid[s, i], grid[s, i + 1], grid[s + 1, i + 1]);
					if (s < stacks - 1) b.Tri(grid[s, i], grid[s + 1, i + 1], grid[s + 1, i]);
				}
			return b.Build(device);
		}
	}
}
