// Value types, exceptions and small classes of Microsoft.DirectX.Direct3D.
// Struct-vs-class and the layouts of structs passed to d3d9 match the real assembly.

using System;
using System.Collections;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace Microsoft.DirectX.Direct3D {

	[Serializable]
	public class GraphicsException : DirectXException {
		public GraphicsException() { }
		public GraphicsException(string message) : base(message) { }
		public GraphicsException(string message, Exception inner) : base(message, inner) { }
		protected GraphicsException(System.Runtime.Serialization.SerializationInfo info, System.Runtime.Serialization.StreamingContext context) : base(info, context) { }

		public static Exception GetExceptionFromResultInternal(int resultCode) {
			string name;
			GraphicsException e;
			switch ((uint)resultCode) {
				case 0x88760868: e = new DeviceLostException("Device lost."); name = "D3DERR_DEVICELOST"; break;
				case 0x88760869: e = new DeviceNotResetException("Device not reset."); name = "D3DERR_DEVICENOTRESET"; break;
				case 0x8876086A: e = new NotAvailableException("Not available."); name = "D3DERR_NOTAVAILABLE"; break;
				case 0x8876086C: e = new InvalidCallException("Invalid call."); name = "D3DERR_INVALIDCALL"; break;
				case 0x8876017C: e = new OutOfVideoMemoryException("Out of video memory."); name = "D3DERR_OUTOFVIDEOMEMORY"; break;
				case 0x8007000E: e = new GraphicsException("Out of memory."); name = "E_OUTOFMEMORY"; break;
				default: e = new GraphicsException("Error in the application."); name = "error"; break;
			}
			e.ErrorCode = resultCode;
			Com.Log(name + " 0x" + resultCode.ToString("X8") + "\n" + Environment.StackTrace);
			return e;
		}
	}

	[Serializable] public class DeviceLostException : GraphicsException { public DeviceLostException() { } public DeviceLostException(string m) : base(m) { } public DeviceLostException(string m, Exception i) : base(m, i) { } }
	[Serializable] public class DeviceNotResetException : GraphicsException { public DeviceNotResetException() { } public DeviceNotResetException(string m) : base(m) { } public DeviceNotResetException(string m, Exception i) : base(m, i) { } }
	[Serializable] public class NotAvailableException : GraphicsException { public NotAvailableException() { } public NotAvailableException(string m) : base(m) { } public NotAvailableException(string m, Exception i) : base(m, i) { } }
	[Serializable] public class InvalidCallException : GraphicsException { public InvalidCallException() { } public InvalidCallException(string m) : base(m) { } public InvalidCallException(string m, Exception i) : base(m, i) { } }
	[Serializable] public class OutOfVideoMemoryException : GraphicsException { public OutOfVideoMemoryException() { } public OutOfVideoMemoryException(string m) : base(m) { } public OutOfVideoMemoryException(string m, Exception i) : base(m, i) { } }

	// D3DCOLORVALUE
	[StructLayout(LayoutKind.Sequential)]
	internal struct ColorF {
		public float R, G, B, A;
		public static ColorF From(Color c) { ColorF v; v.R = c.R / 255f; v.G = c.G / 255f; v.B = c.B / 255f; v.A = c.A / 255f; return v; }
		static int B8(float f) { return Math.Max(0, Math.Min(255, (int)(f * 255f + 0.5f))); }
		public Color ToColor() { return Color.FromArgb(B8(A), B8(R), B8(G), B8(B)); }
	}

	// Same layout as D3DMATERIAL9, so it is passed to SetMaterial as is.
	[StructLayout(LayoutKind.Sequential)]
	public struct Material {
		ColorF m_Diffuse, m_Ambient, m_Specular, m_Emissive;
		float m_Power;

		public Material() { this = default(Material); }
		public Color Diffuse { get { return m_Diffuse.ToColor(); } set { m_Diffuse = ColorF.From(value); } }
		public Color Ambient { get { return m_Ambient.ToColor(); } set { m_Ambient = ColorF.From(value); } }
		public Color Specular { get { return m_Specular.ToColor(); } set { m_Specular = ColorF.From(value); } }
		public Color Emissive { get { return m_Emissive.ToColor(); } set { m_Emissive = ColorF.From(value); } }
		public float SpecularSharpness { get { return m_Power; } set { m_Power = value; } }
	}

	// Same layout as D3DVIEWPORT9.
	[StructLayout(LayoutKind.Sequential)]
	public struct Viewport {
		int m_X, m_Y, m_Width, m_Height;
		float m_MinZ, m_MaxZ;

		public Viewport() { this = default(Viewport); }
		public int X { get { return m_X; } set { m_X = value; } }
		public int Y { get { return m_Y; } set { m_Y = value; } }
		public int Width { get { return m_Width; } set { m_Width = value; } }
		public int Height { get { return m_Height; } set { m_Height = value; } }
		public float MinZ { get { return m_MinZ; } set { m_MinZ = value; } }
		public float MaxZ { get { return m_MaxZ; } set { m_MaxZ = value; } }
		public override string ToString() { return "X: " + m_X + " Y: " + m_Y + " Width: " + m_Width + " Height: " + m_Height + " MinZ: " + m_MinZ + " MaxZ: " + m_MaxZ; }
	}

	// Same layout as D3DDISPLAYMODE.
	[StructLayout(LayoutKind.Sequential)]
	public struct DisplayMode {
		int m_Width, m_Height, m_RefreshRate;
		Format m_Format;

		public DisplayMode() { this = default(DisplayMode); }
		public int Width { get { return m_Width; } set { m_Width = value; } }
		public int Height { get { return m_Height; } set { m_Height = value; } }
		public int RefreshRate { get { return m_RefreshRate; } set { m_RefreshRate = value; } }
		public Format Format { get { return m_Format; } set { m_Format = value; } }
		public override string ToString() { return "Width: " + m_Width + " Height: " + m_Height + " RefreshRate: " + m_RefreshRate + " Format: " + m_Format; }
	}

	[StructLayout(LayoutKind.Sequential)]
	public struct VertexBufferDescription {
		Format m_Format; ResourceType m_Type; Usage m_Usage; Pool m_Pool; int m_Size; VertexFormats m_VertexFormat;

		public VertexBufferDescription() { this = default(VertexBufferDescription); }
		public Format Format { get { return m_Format; } set { m_Format = value; } }
		public ResourceType Type { get { return m_Type; } set { m_Type = value; } }
		public Usage Usage { get { return m_Usage; } set { m_Usage = value; } }
		public Pool Pool { get { return m_Pool; } set { m_Pool = value; } }
		public int Size { get { return m_Size; } set { m_Size = value; } }
		public VertexFormats VertexFormat { get { return m_VertexFormat; } set { m_VertexFormat = value; } }
	}

	// The D3DCAPS9 fields the programs read. The real struct wraps all of D3DCAPS9.
	[StructLayout(LayoutKind.Sequential)]
	public struct Caps {
		internal DeviceType m_DeviceType;
		internal int m_AdapterOrdinal;
		internal DeviceCaps m_DeviceCaps;
		internal int m_MaxActiveLights;
		internal float m_MaxPointSize;

		public Caps() { this = default(Caps); }
		public DeviceType DeviceType { get { return m_DeviceType; } }
		public int AdapterOrdinal { get { return m_AdapterOrdinal; } }
		public DeviceCaps DeviceCaps { get { return m_DeviceCaps; } }
		public int MaxActiveLights { get { return m_MaxActiveLights; } }
		public float MaxPointSize { get { return m_MaxPointSize; } }

		// Byte offsets into D3DCAPS9 (d3d9caps.h).
		internal static unsafe Caps FromNative(byte* p) {
			Caps c = default(Caps);
			c.m_DeviceType = (DeviceType)(*(int*)(p + 0));
			c.m_AdapterOrdinal = *(int*)(p + 4);
			c.m_DeviceCaps.m_Caps = *(int*)(p + 28);
			c.m_MaxActiveLights = *(int*)(p + 160);
			c.m_MaxPointSize = *(float*)(p + 176);
			return c;
		}
	}

	// D3DCAPS9.DevCaps flags.
	[StructLayout(LayoutKind.Sequential)]
	public struct DeviceCaps {
		internal int m_Caps;

		public DeviceCaps() { m_Caps = 0; }
		bool Has(int bit) { return (m_Caps & bit) != 0; }
		public bool SupportsExecuteSystemMemory { get { return Has(0x10); } }
		public bool SupportsExecuteVideoMemory { get { return Has(0x20); } }
		public bool SupportsTransformedVertexSystemMemory { get { return Has(0x40); } }
		public bool SupportsTransformedVertexVideoMemory { get { return Has(0x80); } }
		public bool SupportsDrawPrimTlVertex { get { return Has(0x400); } }
		public bool CanRenderAfterFlip { get { return Has(0x800); } }
		public bool SupportsHardwareRasterization { get { return Has(0x80000); } }
		public bool SupportsHardwareTransformAndLight { get { return Has(0x10000); } }
		public bool SupportsPureDevice { get { return Has(0x100000); } }
		public bool SupportsDrawPrimitives2 { get { return Has(0x2000); } }
		public bool SupportsDrawPrimitives2Ex { get { return Has(0x8000); } }
	}

	// Marks a return type that shim/tools/AddModOpt turns into `T modopt(type)` after compiling.
	[AttributeUsage(AttributeTargets.ReturnValue)]
	internal sealed class ReturnModOptAttribute : Attribute { public ReturnModOptAttribute(Type modifier) { } }

	public sealed class CustomVertex {
		CustomVertex() { }

		[StructLayout(LayoutKind.Sequential)]
		public struct PositionColored {
			public float X, Y, Z;
			public int Color;
			public static VertexFormats Format = VertexFormats.Position | VertexFormats.Diffuse;

			public PositionColored(Vector3 value, int c) { X = value.X; Y = value.Y; Z = value.Z; Color = c; }
			public PositionColored(float xvalue, float yvalue, float zvalue, int c) { X = xvalue; Y = yvalue; Z = zvalue; Color = c; }
			public static int StrideSize { [return: ReturnModOpt(typeof(Microsoft.VisualC.IsConstModifier))] get { return 16; } }
			public Vector3 Position { get { return new Vector3(X, Y, Z); } set { X = value.X; Y = value.Y; Z = value.Z; } }
		}

		[StructLayout(LayoutKind.Sequential)]
		public struct PositionNormalColored {
			public float X, Y, Z, Nx, Ny, Nz;
			public int Color;
			public static VertexFormats Format = VertexFormats.Position | VertexFormats.Normal | VertexFormats.Diffuse;

			public PositionNormalColored(Vector3 pos, Vector3 nor, int c) { X = pos.X; Y = pos.Y; Z = pos.Z; Nx = nor.X; Ny = nor.Y; Nz = nor.Z; Color = c; }
			public PositionNormalColored(float xvalue, float yvalue, float zvalue, float nxvalue, float nyvalue, float nzvalue, int c) {
				X = xvalue; Y = yvalue; Z = zvalue; Nx = nxvalue; Ny = nyvalue; Nz = nzvalue; Color = c;
			}
			public static int StrideSize { [return: ReturnModOpt(typeof(Microsoft.VisualC.IsConstModifier))] get { return 28; } }
			public Vector3 Position { get { return new Vector3(X, Y, Z); } set { X = value.X; Y = value.Y; Z = value.Z; } }
			public Vector3 Normal { get { return new Vector3(Nx, Ny, Nz); } set { Nx = value.X; Ny = value.Y; Nz = value.Z; } }
		}

		[StructLayout(LayoutKind.Sequential)]
		public struct PositionNormal {
			public float X, Y, Z, Nx, Ny, Nz;
			public static VertexFormats Format = VertexFormats.Position | VertexFormats.Normal;
			public PositionNormal(Vector3 pos, Vector3 nor) { X = pos.X; Y = pos.Y; Z = pos.Z; Nx = nor.X; Ny = nor.Y; Nz = nor.Z; }
			public static int StrideSize { [return: ReturnModOpt(typeof(Microsoft.VisualC.IsConstModifier))] get { return 24; } }
			public Vector3 Position { get { return new Vector3(X, Y, Z); } set { X = value.X; Y = value.Y; Z = value.Z; } }
			public Vector3 Normal { get { return new Vector3(Nx, Ny, Nz); } set { Nx = value.X; Ny = value.Y; Nz = value.Z; } }
		}
	}

	public sealed class PresentParameters : ICloneable {
		public PresentParameters() { BackBufferCount = 1; }
		public PresentParameters(PresentParameters original) {
			BackBufferWidth = original.BackBufferWidth; BackBufferHeight = original.BackBufferHeight;
			BackBufferFormat = original.BackBufferFormat; BackBufferCount = original.BackBufferCount;
			MultiSample = original.MultiSample; MultiSampleQuality = original.MultiSampleQuality;
			SwapEffect = original.SwapEffect; DeviceWindow = original.DeviceWindow; m_hwnd = original.m_hwnd;
			Windowed = original.Windowed; EnableAutoDepthStencil = original.EnableAutoDepthStencil;
			AutoDepthStencilFormat = original.AutoDepthStencilFormat; FullScreenRefreshRateInHz = original.FullScreenRefreshRateInHz;
		}
		public object Clone() { return new PresentParameters(this); }

		public int BackBufferWidth { get; set; }
		public int BackBufferHeight { get; set; }
		public Format BackBufferFormat { get; set; }
		public int BackBufferCount { get; set; }
		public MultiSampleType MultiSample { get; set; }
		public int MultiSampleQuality { get; set; }
		public SwapEffect SwapEffect { get; set; }
		Control m_window; IntPtr m_hwnd;
		public Control DeviceWindow { get { return m_window; } set { m_window = value; m_hwnd = value == null ? IntPtr.Zero : value.Handle; } }
		public IntPtr DeviceWindowHandle { get { return m_hwnd; } set { m_hwnd = value; m_window = null; } }
		public bool Windowed { get; set; }
		public bool EnableAutoDepthStencil { get; set; }
		public DepthFormat AutoDepthStencilFormat { get; set; }
		public int FullScreenRefreshRateInHz { get; set; }

		internal D3DPP ToNative(IntPtr fallbackWindow) {
			D3DPP p = default(D3DPP);
			p.Width = BackBufferWidth; p.Height = BackBufferHeight; p.Format = (int)BackBufferFormat;
			p.Count = BackBufferCount; p.MultiSample = (int)MultiSample; p.MultiSampleQuality = MultiSampleQuality;
			p.SwapEffect = (int)SwapEffect; p.Window = m_hwnd != IntPtr.Zero ? m_hwnd : fallbackWindow;
			p.Windowed = Windowed ? 1 : 0; p.EnableAutoDepthStencil = EnableAutoDepthStencil ? 1 : 0;
			p.AutoDepthStencilFormat = (int)AutoDepthStencilFormat; p.Refresh = FullScreenRefreshRateInHz;
			return p;
		}

		// Device creation and Reset write the values d3d9 picked (e.g. a 0 width) back.
		internal void FromNative(D3DPP p) {
			BackBufferWidth = p.Width; BackBufferHeight = p.Height; BackBufferFormat = (Format)p.Format; BackBufferCount = p.Count;
		}
	}

	// D3DPRESENT_PARAMETERS
	[StructLayout(LayoutKind.Sequential)]
	internal struct D3DPP {
		public int Width, Height, Format, Count, MultiSample, MultiSampleQuality, SwapEffect;
		public IntPtr Window;
		public int Windowed, EnableAutoDepthStencil, AutoDepthStencilFormat, Flags, Refresh, Interval;
	}
}
