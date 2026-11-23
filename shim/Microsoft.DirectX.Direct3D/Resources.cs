// Resource and VertexBuffer.
//
// Lock returns a managed array, as MDX's typed Lock does, and Unlock copies it into the d3d9
// buffer. The array is kept between locks as a mirror of the buffer, so Lock never reads
// back from d3d9. Pool.Default is created in the managed pool instead, so a Reset never fails
// because of a live default-pool buffer (real MDX recreated those itself).

using System;
using System.Runtime.InteropServices;

namespace Microsoft.DirectX.Direct3D {

	public abstract class Resource : MarshalByRefObject {
		internal IntPtr m_ptr;
		internal Device m_device;

		public IntPtr UnmanagedComPointer { get { return m_ptr; } }
		public Device Device { get { return m_device; } }
		public bool Disposed { get { return m_ptr == IntPtr.Zero; } }

		public static bool operator ==(Resource left, Resource right) { return ReferenceEquals(left, right); }
		public static bool operator !=(Resource left, Resource right) { return !ReferenceEquals(left, right); }
		public override bool Equals(object compare) { return ReferenceEquals(this, compare); }
		public override int GetHashCode() { return m_ptr.GetHashCode(); }

		internal void ReleaseNative() {
			IntPtr p = m_ptr;
			m_ptr = IntPtr.Zero;
			Com.Release(p); // d3d9 objects are safe to release from the finalizer thread in Wine
		}
	}

	public sealed class VertexBuffer : Resource, IDisposable {
		readonly Type m_type;
		readonly int m_numVerts;
		internal readonly int m_stride;
		readonly Usage m_usage;
		readonly Pool m_pool;
		readonly VertexFormats m_fvf;
		Array m_mirror, m_locked;
		int m_lockedStart;
		LockFlags m_lockFlags;

		public VertexBuffer(Type typeVertexType, int numVerts, Device device, Usage usage, VertexFormats vertexFormat, Pool pool) {
			m_type = typeVertexType;
			m_numVerts = numVerts;
			m_stride = Marshal.SizeOf(typeVertexType);
			m_device = device;
			m_usage = usage;
			m_pool = pool;
			m_fvf = vertexFormat;
			if (pool == Pool.Default) { pool = Pool.Managed; usage &= ~Usage.Dynamic; }
			m_ptr = Com.CreateVertexBuffer(device.UnmanagedComPointer, Math.Max(1, numVerts) * m_stride, (int)usage, (int)vertexFormat, (int)pool);
		}

		public VertexBufferDescription Description {
			get {
				var d = new VertexBufferDescription();
				d.Format = Format.VertexData; d.Type = ResourceType.VertexBuffer; d.Usage = m_usage; d.Pool = m_pool;
				d.Size = m_numVerts * m_stride; d.VertexFormat = m_fvf;
				return d;
			}
		}

		public int NumberVertices { get { return m_numVerts; } }

		public Array Lock(int offsetToLock, LockFlags flags) {
			if (m_mirror == null) m_mirror = Array.CreateInstance(m_type, m_numVerts);
			int start = offsetToLock / m_stride;
			m_lockFlags = flags;
			m_lockedStart = start;
			if (start == 0) {
				m_locked = m_mirror;
			} else {
				m_locked = Array.CreateInstance(m_type, Math.Max(0, m_numVerts - start));
				Array.Copy(m_mirror, start, m_locked, 0, m_locked.Length);
			}
			return m_locked;
		}

		public void Unlock() {
			if (m_locked == null) return;
			Array a = m_locked;
			m_locked = null;
			if ((m_lockFlags & LockFlags.ReadOnly) != 0) return;
			if (a != m_mirror) Array.Copy(a, 0, m_mirror, m_lockedStart, a.Length);
			Com.Upload(m_ptr, m_lockedStart * m_stride, a, a.Length * m_stride);
		}

		public void Dispose() {
			ReleaseNative();
			GC.SuppressFinalize(this);
		}
		~VertexBuffer() { ReleaseNative(); }
	}
}
