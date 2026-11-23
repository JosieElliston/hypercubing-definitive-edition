// Manager (IDirect3D9) and the adapter / display-mode collections.

using System;
using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace Microsoft.DirectX.Direct3D {

	public sealed unsafe class Manager : MarshalByRefObject {
		Manager() { }

		[DllImport("d3d9.dll")]
		static extern IntPtr Direct3DCreate9(uint sdkVersion);

		static IntPtr s_d3d;
		internal static IntPtr D3D {
			get {
				if (s_d3d == IntPtr.Zero) {
					s_d3d = Direct3DCreate9(32); // D3D_SDK_VERSION
					if (s_d3d == IntPtr.Zero) throw new GraphicsException("Direct3DCreate9 failed.");
				}
				return s_d3d;
			}
		}

		// IDirect3D9 slots
		const int GetAdapterCountSlot = 4, GetAdapterModeCountSlot = 6, EnumAdapterModesSlot = 7, GetAdapterDisplayModeSlot = 8,
			CheckDeviceTypeSlot = 9, CheckDeviceFormatSlot = 10, CheckDepthStencilMatchSlot = 12, GetDeviceCapsSlot = 14;
		internal const int CreateDeviceSlot = 16;

		public static AdapterListCollection Adapters { get { return new AdapterListCollection(); } }

		internal static int AdapterCount { get { IntPtr d = D3D; return (int)((delegate* unmanaged[Stdcall]<IntPtr, uint>)Com.Fn(d, GetAdapterCountSlot))(d); } }

		internal static DisplayMode GetAdapterDisplayMode(int adapter) {
			IntPtr d = D3D;
			DisplayMode m;
			Com.Check(((delegate* unmanaged[Stdcall]<IntPtr, uint, DisplayMode*, int>)Com.Fn(d, GetAdapterDisplayModeSlot))(d, (uint)adapter, &m));
			return m;
		}

		internal static List<DisplayMode> EnumModes(int adapter, Format format) {
			IntPtr d = D3D;
			var list = new List<DisplayMode>();
			uint n = ((delegate* unmanaged[Stdcall]<IntPtr, uint, int, uint>)Com.Fn(d, GetAdapterModeCountSlot))(d, (uint)adapter, (int)format);
			for (uint i = 0; i < n; i++) {
				DisplayMode m;
				if (((delegate* unmanaged[Stdcall]<IntPtr, uint, int, uint, DisplayMode*, int>)Com.Fn(d, EnumAdapterModesSlot))(d, (uint)adapter, (int)format, i, &m) == 0)
					list.Add(m);
			}
			return list;
		}

		public static bool CheckDeviceType(int adapter, DeviceType checkType, Format displayFormat, Format backBufferFormat, bool windowed) {
			IntPtr d = D3D;
			return ((delegate* unmanaged[Stdcall]<IntPtr, uint, int, int, int, int, int>)Com.Fn(d, CheckDeviceTypeSlot))
				(d, (uint)adapter, (int)checkType, (int)displayFormat, (int)backBufferFormat, windowed ? 1 : 0) == 0;
		}

		static bool CheckFormat(int adapter, DeviceType deviceType, Format adapterFormat, Usage usage, ResourceType resourceType, int checkFormat) {
			IntPtr d = D3D;
			return ((delegate* unmanaged[Stdcall]<IntPtr, uint, int, int, uint, int, int, int>)Com.Fn(d, CheckDeviceFormatSlot))
				(d, (uint)adapter, (int)deviceType, (int)adapterFormat, (uint)usage, (int)resourceType, checkFormat) == 0;
		}
		public static bool CheckDeviceFormat(int adapter, DeviceType deviceType, Format adapterFormat, Usage usage, ResourceType resourceType, Format checkFormat) {
			return CheckFormat(adapter, deviceType, adapterFormat, usage, resourceType, (int)checkFormat);
		}
		public static bool CheckDeviceFormat(int adapter, DeviceType deviceType, Format adapterFormat, Usage usage, ResourceType resourceType, DepthFormat checkFormat) {
			return CheckFormat(adapter, deviceType, adapterFormat, usage, resourceType, (int)checkFormat);
		}

		public static bool CheckDepthStencilMatch(int adapter, DeviceType deviceType, Format adapterFormat, Format renderTargetFormat, DepthFormat depthStencilFormat) {
			IntPtr d = D3D;
			return ((delegate* unmanaged[Stdcall]<IntPtr, uint, int, int, int, int, int>)Com.Fn(d, CheckDepthStencilMatchSlot))
				(d, (uint)adapter, (int)deviceType, (int)adapterFormat, (int)renderTargetFormat, (int)depthStencilFormat) == 0;
		}

		public static Caps GetDeviceCaps(int adapter, DeviceType deviceType) {
			IntPtr d = D3D;
			byte* buf = stackalloc byte[512]; // D3DCAPS9 is 304 bytes
			Com.Check(((delegate* unmanaged[Stdcall]<IntPtr, uint, int, byte*, int>)Com.Fn(d, GetDeviceCapsSlot))(d, (uint)adapter, (int)deviceType, buf));
			return Caps.FromNative(buf);
		}
	}

	public sealed class AdapterListCollection : IEnumerable {
		internal AdapterListCollection() { }
		public int Count { get { return Manager.AdapterCount; } }
		public AdapterInformation this[int index] { get { return new AdapterInformation(index); } }
		public AdapterInformation Default { get { return this[0]; } }
		public IEnumerator GetEnumerator() {
			var l = new List<AdapterInformation>();
			for (int i = 0; i < Count; i++) l.Add(this[i]);
			return l.GetEnumerator();
		}
	}

	public sealed class AdapterInformation {
		readonly int m_adapter;
		internal AdapterInformation(int adapter) { m_adapter = adapter; }
		public int Adapter { get { return m_adapter; } }
		public DisplayMode CurrentDisplayMode { get { return Manager.GetAdapterDisplayMode(m_adapter); } }
		public DisplayModeCollection SupportedDisplayModes { get { return new DisplayModeCollection(m_adapter); } }
		public override string ToString() { return "Adapter " + m_adapter; }
	}

	// Only X8R8G8B8 modes, one per width x height, at most 64. Why? The programs' DX sample
	// framework copies unique modes into a fixed DisplayMode[100] and only uses them for
	// full screen, which these windowed programs never enter; Wine on a Mac can list more.
	public sealed class DisplayModeCollection : IEnumerable {
		readonly List<DisplayMode> m_modes = new List<DisplayMode>();
		internal DisplayModeCollection(int adapter) {
			var seen = new HashSet<long>();
			foreach (DisplayMode m in Manager.EnumModes(adapter, Format.X8R8G8B8)) {
				if (m_modes.Count >= 64) break;
				if (seen.Add(((long)m.Width << 32) | (uint)m.Height)) m_modes.Add(m);
			}
		}
		public int Count { get { return m_modes.Count; } }
		public IEnumerator GetEnumerator() { return ((IEnumerable)m_modes).GetEnumerator(); }
	}
}
