// Device (IDirect3DDevice9) plus its Transforms, RenderStateManager and Lights helpers.
//
// Differences from the real Managed DirectX, all on purpose:
// - After any Reset, the render states, transforms, material and lights set through this
//   class are applied again (not the viewport, which Reset sets to the new back buffer).
//   Real MDX left the device in its default state, and the programs restore state themselves,
//   so this only matters if a program draws between an automatic resize Reset and its own.
// - With MDXSHIM_DUMP=<dir>, every Present writes the back buffer to <dir>/<exe name>.bmp
//   (overwritten each frame). Used to check rendering without a screenshot.
// - With MDXSHIM_LOG set, failed calls and resizes are logged to stderr.
// - The render control may be re-laid out so it doesn't sit under docked siblings (FillFix.cs).

using System;
using System.Collections;
using System.Collections.Generic;
using System.ComponentModel;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace Microsoft.DirectX.Direct3D {

	public sealed unsafe class Device : MarshalByRefObject, IDisposable {
		IntPtr m_dev;
		Control m_window;
		IntPtr m_focus;
		D3DPP m_pp;
		VertexFormats m_fvf;
		Material m_material; bool m_hasMaterial;
		Viewport m_viewport;
		internal readonly Dictionary<int, int> m_renderStates = new Dictionary<int, int>();
		internal readonly Dictionary<int, Matrix> m_transforms = new Dictionary<int, Matrix>();
		readonly LightsCollection m_lights;
		readonly Transforms m_transform;
		readonly RenderStateManager m_renderState;

		public event EventHandler Disposing;
		public event CancelEventHandler DeviceResizing;
		public event EventHandler DeviceReset;
		public event EventHandler DeviceLost;

		public Device(int adapter, DeviceType deviceType, Control renderWindow, CreateFlags behaviorFlags, params PresentParameters[] presentationParameters)
			: this(adapter, deviceType, renderWindow, renderWindow.Handle, behaviorFlags, presentationParameters) { }

		public Device(int adapter, DeviceType deviceType, IntPtr renderWindowHandle, CreateFlags behaviorFlags, params PresentParameters[] presentationParameters)
			: this(adapter, deviceType, Control.FromHandle(renderWindowHandle), renderWindowHandle, behaviorFlags, presentationParameters) { }

		Device(int adapter, DeviceType deviceType, Control window, IntPtr focus, CreateFlags flags, PresentParameters[] pps) {
			m_lights = new LightsCollection(this);
			m_transform = new Transforms(this);
			m_renderState = new RenderStateManager(this);
			m_focus = focus;
			PresentParameters pp = pps[0];
			D3DPP p = pp.ToNative(focus);
			IntPtr d3d = Manager.D3D, dev;
			Com.Check(((delegate* unmanaged[Stdcall]<IntPtr, uint, int, IntPtr, uint, D3DPP*, IntPtr*, int>)Com.Fn(d3d, Manager.CreateDeviceSlot))
				(d3d, (uint)adapter, (int)deviceType, focus, (uint)flags, &p, &dev));
			m_dev = dev;
			m_pp = p;
			pp.FromNative(p);
			m_viewport.Width = p.Width; m_viewport.Height = p.Height; m_viewport.MaxZ = 1;
			Com.Log("device " + p.Width + "x" + p.Height + " format " + (Format)p.Format + " depth " + (DepthFormat)p.AutoDepthStencilFormat +
				" flags " + flags + (IntPtr.Size == 8 ? " (64-bit)" : " (32-bit)"));
			// Real MDX resets the device itself when the render window is resized, unless a
			// DeviceResizing handler cancels.
			m_window = (p.Window != focus ? Control.FromHandle(p.Window) : null) ?? window;
			if (m_window != null) m_window.Resize += OnWindowResize;
			FillFix.Attach(m_window);
		}

		public IntPtr UnmanagedComPointer { get { return m_dev; } }

		void OnWindowResize(object sender, EventArgs e) {
			if (m_dev == IntPtr.Zero || m_pp.Windowed == 0 || m_window.WindowState() == FormWindowState.Minimized) return;
			Size s = m_window.ClientSize;
			if (s.Width <= 0 || s.Height <= 0 || (s.Width == m_pp.Width && s.Height == m_pp.Height)) return;
			var args = new CancelEventArgs();
			if (DeviceResizing != null) DeviceResizing(this, args);
			if (args.Cancel) return;
			D3DPP p = m_pp;
			p.Width = s.Width; p.Height = s.Height;
			Com.Log("auto reset to " + s.Width + "x" + s.Height);
			try { DoReset(p); } catch (GraphicsException) { }
		}

		public void Reset(params PresentParameters[] presentationParameters) {
			PresentParameters pp = presentationParameters[0];
			D3DPP p = pp.ToNative(m_focus);
			p = DoReset(p);
			pp.FromNative(p);
		}

		D3DPP DoReset(D3DPP p) {
			if (DeviceLost != null) DeviceLost(this, EventArgs.Empty);
			Com.Check(((delegate* unmanaged[Stdcall]<IntPtr, D3DPP*, int>)Com.Fn(m_dev, Com.DevReset))(m_dev, &p));
			m_pp = p;
			m_viewport = default(Viewport);
			m_viewport.Width = p.Width; m_viewport.Height = p.Height; m_viewport.MaxZ = 1;
			Com.Log("reset " + p.Width + "x" + p.Height);
			foreach (var kv in m_renderStates) SetRenderStateRaw(kv.Key, kv.Value);
			foreach (var kv in m_transforms) { Matrix m = kv.Value; SetTransformRaw(kv.Key, &m); }
			if (m_hasMaterial) { Material mt = m_material; ((delegate* unmanaged[Stdcall]<IntPtr, Material*, int>)Com.Fn(m_dev, Com.DevSetMaterial))(m_dev, &mt); }
			m_lights.Reapply();
			if (DeviceReset != null) DeviceReset(this, EventArgs.Empty);
			return p;
		}

		public void TestCooperativeLevel() {
			Com.Check(((delegate* unmanaged[Stdcall]<IntPtr, int>)Com.Fn(m_dev, Com.DevTestCooperativeLevel))(m_dev));
		}

		public void BeginScene() { Com.Check(((delegate* unmanaged[Stdcall]<IntPtr, int>)Com.Fn(m_dev, Com.DevBeginScene))(m_dev)); }
		public void EndScene() { Com.Check(((delegate* unmanaged[Stdcall]<IntPtr, int>)Com.Fn(m_dev, Com.DevEndScene))(m_dev)); }

		public void Clear(ClearFlags flags, Color color, float zdepth, int stencil) { Clear(flags, color.ToArgb(), zdepth, stencil); }
		public void Clear(ClearFlags flags, int color, float zdepth, int stencil) {
			Com.Check(((delegate* unmanaged[Stdcall]<IntPtr, uint, void*, uint, uint, float, uint, int>)Com.Fn(m_dev, Com.DevClear))
				(m_dev, 0, null, (uint)flags, (uint)color, zdepth, (uint)stencil));
		}

		public void Present() {
			if (s_dumpDir != null) DumpBackBuffer();
			Com.Check(((delegate* unmanaged[Stdcall]<IntPtr, void*, void*, IntPtr, void*, int>)Com.Fn(m_dev, Com.DevPresent))(m_dev, null, null, IntPtr.Zero, null));
		}

		public void SetTransform(TransformType state, Matrix matrix) {
			m_transforms[(int)state] = matrix;
			SetTransformRaw((int)state, &matrix);
		}
		internal Matrix GetTransformCached(TransformType state) {
			Matrix m;
			return m_transforms.TryGetValue((int)state, out m) ? m : Matrix.Identity;
		}
		void SetTransformRaw(int state, Matrix* m) {
			((delegate* unmanaged[Stdcall]<IntPtr, int, Matrix*, int>)Com.Fn(m_dev, Com.DevSetTransform))(m_dev, state, m);
		}

		internal void SetRenderState(int state, int value) {
			m_renderStates[state] = value;
			SetRenderStateRaw(state, value);
		}
		internal int GetRenderStateCached(int state, int dflt) {
			int v;
			return m_renderStates.TryGetValue(state, out v) ? v : dflt;
		}
		void SetRenderStateRaw(int state, int value) {
			((delegate* unmanaged[Stdcall]<IntPtr, int, uint, int>)Com.Fn(m_dev, Com.DevSetRenderState))(m_dev, state, (uint)value);
		}

		public Material Material {
			get { return m_material; }
			set {
				m_material = value; m_hasMaterial = true;
				Com.Check(((delegate* unmanaged[Stdcall]<IntPtr, Material*, int>)Com.Fn(m_dev, Com.DevSetMaterial))(m_dev, &value));
			}
		}

		public Viewport Viewport {
			get { return m_viewport; }
			set {
				m_viewport = value;
				Com.Check(((delegate* unmanaged[Stdcall]<IntPtr, Viewport*, int>)Com.Fn(m_dev, Com.DevSetViewport))(m_dev, &value));
			}
		}

		public VertexFormats VertexFormat {
			get { return m_fvf; }
			set {
				m_fvf = value;
				Com.Check(((delegate* unmanaged[Stdcall]<IntPtr, uint, int>)Com.Fn(m_dev, Com.DevSetFVF))(m_dev, (uint)value));
			}
		}

		public void SetStreamSource(int streamNumber, VertexBuffer streamData, int offsetInBytes, int stride) {
			IntPtr vb = streamData == null ? IntPtr.Zero : streamData.UnmanagedComPointer;
			Com.Check(((delegate* unmanaged[Stdcall]<IntPtr, uint, IntPtr, uint, uint, int>)Com.Fn(m_dev, Com.DevSetStreamSource))
				(m_dev, (uint)streamNumber, vb, (uint)offsetInBytes, (uint)stride));
		}
		public void SetStreamSource(int streamNumber, VertexBuffer streamData, int offsetInBytes) {
			SetStreamSource(streamNumber, streamData, offsetInBytes, streamData == null ? 0 : streamData.m_stride);
		}

		public void DrawPrimitives(PrimitiveType primitiveType, int startVertex, int primitiveCount) {
			Com.Check(((delegate* unmanaged[Stdcall]<IntPtr, int, uint, uint, int>)Com.Fn(m_dev, Com.DevDrawPrimitive))
				(m_dev, (int)primitiveType, (uint)startVertex, (uint)primitiveCount));
		}

		public Caps DeviceCaps {
			get {
				byte* buf = stackalloc byte[512];
				Com.Check(((delegate* unmanaged[Stdcall]<IntPtr, byte*, int>)Com.Fn(m_dev, Com.DevGetDeviceCaps))(m_dev, buf));
				return Caps.FromNative(buf);
			}
		}

		public LightsCollection Lights { get { return m_lights; } }
		public Transforms Transform { get { return m_transform; } }
		public RenderStateManager RenderState { get { return m_renderState; } }
		public PresentParameters PresentationParameters {
			get {
				var pp = new PresentParameters();
				pp.FromNative(m_pp);
				pp.Windowed = m_pp.Windowed != 0; pp.SwapEffect = (SwapEffect)m_pp.SwapEffect;
				pp.EnableAutoDepthStencil = m_pp.EnableAutoDepthStencil != 0; pp.AutoDepthStencilFormat = (DepthFormat)m_pp.AutoDepthStencilFormat;
				return pp;
			}
		}

		public bool Disposed { get { return m_dev == IntPtr.Zero; } }

		public void Dispose() {
			if (m_dev == IntPtr.Zero) return;
			if (Disposing != null) Disposing(this, EventArgs.Empty);
			if (m_window != null) m_window.Resize -= OnWindowResize;
			Com.Release(m_dev);
			m_dev = IntPtr.Zero;
		}

		public static bool operator ==(Device left, Device right) { return ReferenceEquals(left, right); }
		public static bool operator !=(Device left, Device right) { return !ReferenceEquals(left, right); }
		public override bool Equals(object compare) { return ReferenceEquals(this, compare); }
		public override int GetHashCode() { return m_dev.GetHashCode(); }

		// ---- back buffer dump (MDXSHIM_DUMP) ----

		static readonly string s_dumpDir = UnixToWine(Environment.GetEnvironmentVariable("MDXSHIM_DUMP"));

		// A Unix path would otherwise land on the current drive (C:\tmp\... inside the prefix).
		static string UnixToWine(string p) { return p != null && p.StartsWith("/") ? "Z:" + p.Replace('/', '\\') : p; }

		[StructLayout(LayoutKind.Sequential)]
		struct SurfaceDesc { public int Format, Type, Usage, Pool, MultiSampleType, MultiSampleQuality, Width, Height; }
		[StructLayout(LayoutKind.Sequential)]
		struct LockedRect { public int Pitch; public byte* Bits; }

		void DumpBackBuffer() {
			IntPtr bb = IntPtr.Zero, off = IntPtr.Zero;
			try {
				if (((delegate* unmanaged[Stdcall]<IntPtr, uint, uint, int, IntPtr*, int>)Com.Fn(m_dev, Com.DevGetBackBuffer))(m_dev, 0, 0, 0, &bb) < 0) return;
				SurfaceDesc d;
				if (((delegate* unmanaged[Stdcall]<IntPtr, SurfaceDesc*, int>)Com.Fn(bb, 12))(bb, &d) < 0) return;
				if (((delegate* unmanaged[Stdcall]<IntPtr, uint, uint, int, int, IntPtr*, IntPtr, int>)Com.Fn(m_dev, Com.DevCreateOffscreenPlainSurface))
					(m_dev, (uint)d.Width, (uint)d.Height, d.Format, 2 /* D3DPOOL_SYSTEMMEM */, &off, IntPtr.Zero) < 0) return;
				if (((delegate* unmanaged[Stdcall]<IntPtr, IntPtr, IntPtr, int>)Com.Fn(m_dev, Com.DevGetRenderTargetData))(m_dev, bb, off) < 0) return;
				LockedRect lr;
				if (((delegate* unmanaged[Stdcall]<IntPtr, LockedRect*, void*, uint, int>)Com.Fn(off, 13))(off, &lr, null, 16 /* READONLY */) < 0) return;
				try { WriteBmp(d.Width, d.Height, lr); }
				finally { ((delegate* unmanaged[Stdcall]<IntPtr, int>)Com.Fn(off, 14))(off); }
			} catch (Exception e) {
				Com.Log("dump failed: " + e.Message);
			} finally {
				Com.Release(off);
				Com.Release(bb);
			}
		}

		// 32-bit top-down BMP; X8R8G8B8 / A8R8G8B8 rows are already BGRA in memory.
		static void WriteBmp(int w, int h, LockedRect lr) {
			string name = Path.GetFileNameWithoutExtension(System.Reflection.Assembly.GetEntryAssembly()?.Location ?? "mdx");
			string path = Path.Combine(s_dumpDir, name + ".bmp"), tmp = path + ".tmp";
			Directory.CreateDirectory(s_dumpDir);
			int row = w * 4, size = 54 + row * h;
			using (var f = new BinaryWriter(File.Create(tmp))) {
				f.Write((ushort)0x4D42); f.Write(size); f.Write(0); f.Write(54);
				f.Write(40); f.Write(w); f.Write(-h); f.Write((ushort)1); f.Write((ushort)32);
				f.Write(0); f.Write(row * h); f.Write(2835); f.Write(2835); f.Write(0); f.Write(0);
				byte[] line = new byte[row];
				for (int y = 0; y < h; y++) {
					Marshal.Copy((IntPtr)(lr.Bits + (long)y * lr.Pitch), line, 0, row);
					for (int x = 3; x < row; x += 4) line[x] = 255;
					f.Write(line);
				}
			}
			if (File.Exists(path)) File.Delete(path);
			File.Move(tmp, path);
		}
	}

	internal static class ControlExt {
		public static FormWindowState WindowState(this Control c) {
			Form f = c.FindForm();
			return f == null ? FormWindowState.Normal : f.WindowState;
		}
	}

	public sealed class Transforms {
		readonly Device m_device;
		internal Transforms(Device device) { m_device = device; }
		public Matrix World { get { return m_device.GetTransformCached(TransformType.World); } set { m_device.SetTransform(TransformType.World, value); } }
		public Matrix View { get { return m_device.GetTransformCached(TransformType.View); } set { m_device.SetTransform(TransformType.View, value); } }
		public Matrix Projection { get { return m_device.GetTransformCached(TransformType.Projection); } set { m_device.SetTransform(TransformType.Projection, value); } }
	}

	// D3DRENDERSTATETYPE values from d3d9types.h.
	public sealed class RenderStateManager {
		readonly Device m_d;
		internal RenderStateManager(Device device) { m_d = device; }
		const int ZENABLE = 7, FILLMODE = 8, SRCBLEND = 19, DESTBLEND = 20, CULLMODE = 22, ALPHABLENDENABLE = 27,
			SPECULARENABLE = 29, LIGHTING = 137, AMBIENT = 139, SPECULARMATERIALSOURCE = 146, POINTSIZE = 154, POINTSCALEENABLE = 157;
		void Set(int s, int v) { m_d.SetRenderState(s, v); }
		void Set(int s, bool v) { m_d.SetRenderState(s, v ? 1 : 0); }
		unsafe void Set(int s, float v) { m_d.SetRenderState(s, *(int*)&v); }
		bool B(int s, bool dflt) { return m_d.GetRenderStateCached(s, dflt ? 1 : 0) != 0; }
		int I(int s, int dflt) { return m_d.GetRenderStateCached(s, dflt); }
		unsafe float F(int s, float dflt) { int v = m_d.GetRenderStateCached(s, *(int*)&dflt); return *(float*)&v; }

		public bool ZBufferEnable { get { return B(ZENABLE, true); } set { Set(ZENABLE, value); } }
		public FillMode FillMode { get { return (FillMode)I(FILLMODE, 3); } set { Set(FILLMODE, (int)value); } }
		public Blend SourceBlend { get { return (Blend)I(SRCBLEND, 2); } set { Set(SRCBLEND, (int)value); } }
		public Blend DestinationBlend { get { return (Blend)I(DESTBLEND, 1); } set { Set(DESTBLEND, (int)value); } }
		public Cull CullMode { get { return (Cull)I(CULLMODE, 3); } set { Set(CULLMODE, (int)value); } }
		public bool AlphaBlendEnable { get { return B(ALPHABLENDENABLE, false); } set { Set(ALPHABLENDENABLE, value); } }
		public bool SpecularEnable { get { return B(SPECULARENABLE, false); } set { Set(SPECULARENABLE, value); } }
		public bool Lighting { get { return B(LIGHTING, true); } set { Set(LIGHTING, value); } }
		public Color Ambient { get { return Color.FromArgb(I(AMBIENT, 0)); } set { Set(AMBIENT, value.ToArgb()); } }
		public int AmbientColor { get { return I(AMBIENT, 0); } set { Set(AMBIENT, value); } }
		public ColorSource SpecularMaterialSource { get { return (ColorSource)I(SPECULARMATERIALSOURCE, 2); } set { Set(SPECULARMATERIALSOURCE, (int)value); } }
		public float PointSize { get { return F(POINTSIZE, 1f); } set { Set(POINTSIZE, value); } }
		public bool PointScaleEnable { get { return B(POINTSCALEENABLE, false); } set { Set(POINTSCALEENABLE, value); } }
	}

	public sealed class LightsCollection : IEnumerable {
		readonly Device m_device;
		readonly Dictionary<int, Light> m_lights = new Dictionary<int, Light>();
		internal LightsCollection(Device device) { m_device = device; }
		public Light this[int index] {
			get {
				Light l;
				if (!m_lights.TryGetValue(index, out l)) m_lights[index] = l = new Light(m_device, index);
				return l;
			}
		}
		public int Count { get { return m_device.DeviceCaps.MaxActiveLights; } }
		public IEnumerator GetEnumerator() { return m_lights.Values.GetEnumerator(); }
		internal void Reapply() { foreach (Light l in m_lights.Values) l.Reapply(); }
	}

	// Setters apply at once, as in MDX 1.1 (Update and Commit only re-send).
	public sealed unsafe class Light {
		[StructLayout(LayoutKind.Sequential)]
		struct D3DLIGHT9 {
			public int Type;
			public ColorF Diffuse, Specular, Ambient;
			public Vector3 Position, Direction;
			public float Range, Falloff, Attenuation0, Attenuation1, Attenuation2, Theta, Phi;
		}

		readonly Device m_device;
		readonly int m_index;
		D3DLIGHT9 m_l;
		bool m_set, m_enabled, m_enableSet;

		internal Light(Device device, int index) { m_device = device; m_index = index; }

		void Apply() {
			m_set = true;
			D3DLIGHT9 l = m_l;
			// Fails (ignored) until a valid Type is set; the programs set Type first.
			((delegate* unmanaged[Stdcall]<IntPtr, uint, D3DLIGHT9*, int>)Com.Fn(m_device.UnmanagedComPointer, Com.DevSetLight))(m_device.UnmanagedComPointer, (uint)m_index, &l);
		}
		void ApplyEnable() {
			m_enableSet = true;
			((delegate* unmanaged[Stdcall]<IntPtr, uint, int, int>)Com.Fn(m_device.UnmanagedComPointer, Com.DevLightEnable))(m_device.UnmanagedComPointer, (uint)m_index, m_enabled ? 1 : 0);
		}
		internal void Reapply() { if (m_set) Apply(); if (m_enableSet) ApplyEnable(); }

		public void Update() { Apply(); }
		public void Commit() { Apply(); }

		public LightType Type { get { return (LightType)m_l.Type; } set { m_l.Type = (int)value; Apply(); } }
		public Color Diffuse { get { return m_l.Diffuse.ToColor(); } set { m_l.Diffuse = ColorF.From(value); Apply(); } }
		public Color Specular { get { return m_l.Specular.ToColor(); } set { m_l.Specular = ColorF.From(value); Apply(); } }
		public Color Ambient { get { return m_l.Ambient.ToColor(); } set { m_l.Ambient = ColorF.From(value); Apply(); } }
		public Vector3 Position { get { return m_l.Position; } set { m_l.Position = value; Apply(); } }
		public Vector3 Direction { get { return m_l.Direction; } set { m_l.Direction = value; Apply(); } }
		public float Range { get { return m_l.Range; } set { m_l.Range = value; Apply(); } }
		public float Falloff { get { return m_l.Falloff; } set { m_l.Falloff = value; Apply(); } }
		public float Attenuation0 { get { return m_l.Attenuation0; } set { m_l.Attenuation0 = value; Apply(); } }
		public float Attenuation1 { get { return m_l.Attenuation1; } set { m_l.Attenuation1 = value; Apply(); } }
		public float Attenuation2 { get { return m_l.Attenuation2; } set { m_l.Attenuation2 = value; Apply(); } }
		public float InnerConeAngle { get { return m_l.Theta; } set { m_l.Theta = value; Apply(); } }
		public float OuterConeAngle { get { return m_l.Phi; } set { m_l.Phi = value; Apply(); } }
		public bool Enabled { get { return m_enabled; } set { m_enabled = value; ApplyEnable(); } }
	}
}
