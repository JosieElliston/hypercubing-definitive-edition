// Raw Direct3D 9 COM access, compiled into both Direct3D and Direct3DX (internal to each).
//
// Calls go through vtable slots with C# function pointers, so there is no interop library and
// no marshaling. Slot numbers are the method's position in d3d9.h's interface declaration,
// counting IUnknown's three methods first. stdcall is ignored on x64.

using System;
using System.Runtime.InteropServices;

namespace Microsoft.DirectX.Direct3D {
	internal static unsafe class Com {
		public static void* Fn(IntPtr obj, int slot) { return (*(void***)obj)[slot]; }

		public static uint Release(IntPtr obj) {
			if (obj == IntPtr.Zero) return 0;
			return ((delegate* unmanaged[Stdcall]<IntPtr, uint>)Fn(obj, 2))(obj);
		}

		public static void Check(int hr) {
			if (hr < 0) throw GraphicsException.GetExceptionFromResultInternal(hr);
		}

		// IDirect3DDevice9 slots
		public const int DevTestCooperativeLevel = 3, DevGetDeviceCaps = 7, DevReset = 16, DevPresent = 17,
			DevGetBackBuffer = 18, DevCreateVertexBuffer = 26, DevCreateIndexBuffer = 27,
			DevGetRenderTargetData = 32, DevCreateOffscreenPlainSurface = 36,
			DevBeginScene = 41, DevEndScene = 42, DevClear = 43, DevSetTransform = 44, DevSetViewport = 47,
			DevSetMaterial = 49, DevSetLight = 51, DevLightEnable = 53, DevSetRenderState = 57,
			DevDrawPrimitive = 81, DevDrawIndexedPrimitive = 82, DevSetFVF = 89,
			DevSetStreamSource = 100, DevSetIndices = 104;

		// IDirect3DVertexBuffer9 / IDirect3DIndexBuffer9 slots (after IDirect3DResource9's 8)
		public const int BufLock = 11, BufUnlock = 12;

		public static IntPtr CreateVertexBuffer(IntPtr dev, int length, int usage, int fvf, int pool) {
			IntPtr vb;
			Check(((delegate* unmanaged[Stdcall]<IntPtr, uint, uint, uint, int, IntPtr*, IntPtr, int>)Fn(dev, DevCreateVertexBuffer))
				(dev, (uint)length, (uint)usage, (uint)fvf, pool, &vb, IntPtr.Zero));
			return vb;
		}

		public static IntPtr CreateIndexBuffer(IntPtr dev, int length, int usage, bool use32, int pool) {
			IntPtr ib;
			const int D3DFMT_INDEX16 = 101, D3DFMT_INDEX32 = 102;
			Check(((delegate* unmanaged[Stdcall]<IntPtr, uint, uint, int, int, IntPtr*, IntPtr, int>)Fn(dev, DevCreateIndexBuffer))
				(dev, (uint)length, (uint)usage, use32 ? D3DFMT_INDEX32 : D3DFMT_INDEX16, pool, &ib, IntPtr.Zero));
			return ib;
		}

		// Copies `count` bytes from `src` into the buffer at byte offset `offset`.
		public static void Upload(IntPtr buf, int offset, void* src, int count) {
			if (count <= 0) return;
			void* p;
			Check(((delegate* unmanaged[Stdcall]<IntPtr, uint, uint, void**, uint, int>)Fn(buf, BufLock))(buf, (uint)offset, (uint)count, &p, 0));
			Buffer.MemoryCopy(src, p, count, count);
			((delegate* unmanaged[Stdcall]<IntPtr, int>)Fn(buf, BufUnlock))(buf);
		}

		// Copies a managed array (of blittable structs) into the buffer.
		public static void Upload(IntPtr buf, int offset, Array data, int byteCount) {
			GCHandle h = GCHandle.Alloc(data, GCHandleType.Pinned);
			try { Upload(buf, offset, (void*)h.AddrOfPinnedObject(), byteCount); }
			finally { h.Free(); }
		}

		static readonly bool s_log = Environment.GetEnvironmentVariable("MDXSHIM_LOG") != null;
		public static void Log(string msg) { if (s_log) Console.Error.WriteLine("mdxshim: " + msg); }
	}
}
