// TEST INSTRUMENTATION ONLY - not for commit.
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using SharpDX.Direct3D9;

namespace _3dedit {
	public static class TestDump {
		static string dir = Environment.GetEnvironmentVariable("S3D_DUMP_DIR");
		static int frame;
		public static void Log(string s) {
			if (dir == null) return;
			File.AppendAllText(Path.Combine(dir, "log.txt"), DateTime.Now.ToString("HH:mm:ss.fff") + " " + s + "\r\n");
		}
		public static void AfterRender(Device dev) {
			if (dir == null || frame >= 300) return;
			frame++;
			try {
				using (Surface bb = dev.GetBackBuffer(0, 0)) {
					SurfaceDescription d = bb.Description;
					using (Surface sys = Surface.CreateOffscreenPlain(dev, d.Width, d.Height, d.Format, Pool.SystemMemory)) {
						dev.GetRenderTargetData(bb, sys);
						SharpDX.DataRectangle r = sys.LockRectangle(LockFlags.ReadOnly);
						Bitmap bmp = new Bitmap(d.Width, d.Height, PixelFormat.Format32bppRgb);
						BitmapData bd = bmp.LockBits(new Rectangle(0, 0, d.Width, d.Height), ImageLockMode.WriteOnly, PixelFormat.Format32bppRgb);
						byte[] row = new byte[d.Width * 4];
						long nonbg = 0;
						for (int y = 0; y < d.Height; y++) {
							Marshal.Copy(r.DataPointer + y * r.Pitch, row, 0, row.Length);
							Marshal.Copy(row, 0, bd.Scan0 + y * bd.Stride, row.Length);
							for (int x = 0; x < d.Width; x++)
								if (row[4 * x] != row[0] || row[4 * x + 1] != row[1] || row[4 * x + 2] != row[2]) nonbg++;
						}
						bmp.UnlockBits(bd);
						sys.UnlockRectangle();
						string fn = Path.Combine(dir, string.Format("f{0:D4}.png", frame));
						bmp.Save(fn, ImageFormat.Png);
						bmp.Dispose();
						Log(string.Format("frame {0} {1}x{2} {3} bg=({4},{5},{6}) pixels-differing-from-corner={7}", frame, d.Width, d.Height, d.Format, row[2], row[1], row[0], nonbg));
					}
				}
			} catch (Exception e) {
				Log("dump failed: " + e);
			}
		}
	}
}
