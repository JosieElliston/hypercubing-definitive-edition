// Test helper: posts mouse/key messages to the mc7d 3D view without touching the real cursor.
// usage: poke.exe "click x y" "rclick x y" "drag x0 y0 x1 y1" "sleep ms" "key VK" "down VK" "up VK" "resize w h" "close" "info"
// POKE_TITLE=<prefix> picks the top-level window by title prefix (default "MC7D").
// coordinates are client coordinates of the largest child window (the DX view).
using System; using System.Text; using System.Threading; using System.Runtime.InteropServices; using System.Collections.Generic;
class P {
  delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint f);
  [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] static extern IntPtr GetParent(IntPtr h);
  [DllImport("user32.dll")] static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  struct RECT { public int L, T, R, B; }
  static IntPtr L(int x, int y) => (IntPtr)((y << 16) | (x & 0xffff));
  static void Main(string[] args) {
    IntPtr top = IntPtr.Zero;
    EnumWindows((h, l) => { var sb = new StringBuilder(256); GetWindowText(h, sb, 256); if (IsWindowVisible(h) && sb.ToString().StartsWith(Environment.GetEnvironmentVariable("POKE_TITLE") ?? "MC7D")) { top = h; return false; } return true; }, IntPtr.Zero);
    if (top == IntPtr.Zero) {
      Console.WriteLine("no matching window; visible titles:");
      EnumWindows((h, l) => { var sb = new StringBuilder(256); GetWindowText(h, sb, 256); if (IsWindowVisible(h) && sb.Length > 0) Console.WriteLine("  " + sb); return true; }, IntPtr.Zero);
      return;
    }
    IntPtr view = IntPtr.Zero; int best = 0;
    EnumChildWindows(top, (h, l) => { GetClientRect(h, out RECT r); int a = (r.R - r.L) * (r.B - r.T); var c = new StringBuilder(256); GetClassName(h, c, 256);
      if (args.Length > 0 && args[0] == "info") Console.WriteLine($"child {h} {c} {r.R}x{r.B}");
      if (args.Length > 0 && args[0] == "tree") { GetWindowRect(h, out RECT w); GetWindowRect(top, out RECT t); var tx = new StringBuilder(64); GetWindowText(h, tx, 64);
        Console.WriteLine($"{h} parent {GetParent(h)} vis {IsWindowVisible(h)} at ({w.L - t.L},{w.T - t.T}) {w.R - w.L}x{w.B - w.T} {c} '{tx}'"); }
      string want = Environment.GetEnvironmentVariable("POKE_SIZE");
      if (want != null ? (want == $"{r.R}x{r.B}") : (a > best && IsWindowVisible(h))) { best = a; view = h; } return true; }, IntPtr.Zero);
    GetClientRect(view, out RECT vr); Console.WriteLine($"top {top} view {view} {vr.R}x{vr.B}");
    foreach (var a in args) {
      var p = a.Split(' ');
      switch (p[0]) {
        case "click": { int x = int.Parse(p[1]), y = int.Parse(p[2]);
          PostMessage(view, 0x0200, IntPtr.Zero, L(x, y)); Thread.Sleep(30);
          PostMessage(view, 0x0201, (IntPtr)1, L(x, y)); Thread.Sleep(60);
          PostMessage(view, 0x0202, IntPtr.Zero, L(x, y)); Thread.Sleep(30); break; }
        case "rclick": { int x = int.Parse(p[1]), y = int.Parse(p[2]);
          PostMessage(view, 0x0200, IntPtr.Zero, L(x, y)); Thread.Sleep(30);
          PostMessage(view, 0x0204, (IntPtr)2, L(x, y)); Thread.Sleep(60);
          PostMessage(view, 0x0205, IntPtr.Zero, L(x, y)); Thread.Sleep(30); break; }
        case "drag": { int x0 = int.Parse(p[1]), y0 = int.Parse(p[2]), x1 = int.Parse(p[3]), y1 = int.Parse(p[4]);
          PostMessage(view, 0x0201, (IntPtr)1, L(x0, y0));
          for (int i = 1; i <= 20; i++) { Thread.Sleep(20); PostMessage(view, 0x0200, (IntPtr)1, L(x0 + (x1 - x0) * i / 20, y0 + (y1 - y0) * i / 20)); }
          PostMessage(view, 0x0202, IntPtr.Zero, L(x1, y1)); break; }
        case "key": { int vk = int.Parse(p[1]); PostMessage(view, 0x0100, (IntPtr)vk, (IntPtr)1); Thread.Sleep(50); PostMessage(view, 0x0101, (IntPtr)vk, unchecked((IntPtr)0xC0000001)); break; }
        case "down": PostMessage(view, 0x0100, (IntPtr)int.Parse(p[1]), (IntPtr)1); Thread.Sleep(50); break;
        case "up": PostMessage(view, 0x0101, (IntPtr)int.Parse(p[1]), unchecked((IntPtr)0xC0000001)); Thread.Sleep(50); break;
        case "resize": SetWindowPos(top, IntPtr.Zero, 0, 0, int.Parse(p[1]), int.Parse(p[2]), 0x0002 | 0x0004 | 0x0010); break;
        case "close": PostMessage(top, 0x0010, IntPtr.Zero, IntPtr.Zero); break;
        case "sleep": Thread.Sleep(int.Parse(p[1])); break;
      }
      Console.WriteLine("did " + a);
    }
  }
}
