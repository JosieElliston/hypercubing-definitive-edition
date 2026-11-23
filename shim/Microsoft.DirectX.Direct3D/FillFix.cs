// Keeps the D3D render control (and its Fill-docked ancestors) out from under docked siblings.
//
// Why: Wine's Mac driver draws a child window's GL/D3D surface above all sibling windows,
// ignoring z-order. On Windows, overlap between a Fill-docked control and a docked sibling is
// harmless because the sibling is drawn in front. Under Wine it hides the sibling. Seen in
// MPUlt (2026-11-22): the 3D view covered the menu strip and the bottom button panel, because
// wine-mono's dock layout gave the Fill controls the full parent area.
//
// What: for the render control and each Fill-docked ancestor, compute the parent's area minus
// visible siblings docked Top/Bottom/Left/Right. If the Fill control overlaps them, switch it
// to Dock=None and set that rectangle, then keep it updated when the parent or those siblings
// move or resize. Controls that don't overlap anything are left alone.
// MDXSHIM_NOFILLFIX=1 disables this.

using System;
using System.Drawing;
using System.Windows.Forms;

namespace Microsoft.DirectX.Direct3D {
	static class FillFix {
		public static void Attach(Control renderControl) {
			if (renderControl == null || Environment.GetEnvironmentVariable("MDXSHIM_NOFILLFIX") == "1") return;
			for (Control c = renderControl; c != null && c.Parent != null && !(c is Form); c = c.Parent) {
				if (c.Dock != DockStyle.Fill) continue;
				Control target = c, parent = c.Parent;
				EventHandler update = (s, e) => Update(target);
				parent.ClientSizeChanged += update;
				parent.Layout += (s, e) => { if (parent.IsHandleCreated) parent.BeginInvoke(update); };
				foreach (Control sib in parent.Controls) {
					if (sib == target) continue;
					sib.LocationChanged += update;
					sib.SizeChanged += update;
					sib.VisibleChanged += update;
				}
				Update(target);
			}
		}

		static void Update(Control c) {
			Control parent = c.Parent;
			if (parent == null) return;
			Rectangle r = parent.DisplayRectangle;
			int top = r.Top, bottom = r.Bottom, left = r.Left, right = r.Right;
			foreach (Control s in parent.Controls) {
				if (s == c || !s.Visible) continue;
				Rectangle b = s.Bounds;
				switch (s.Dock) {
					case DockStyle.Top: top = Math.Max(top, b.Bottom); break;
					case DockStyle.Bottom: bottom = Math.Min(bottom, b.Top); break;
					case DockStyle.Left: left = Math.Max(left, b.Right); break;
					case DockStyle.Right: right = Math.Min(right, b.Left); break;
				}
			}
			if (right <= left || bottom <= top) return;
			var want = new Rectangle(left, top, right - left, bottom - top);
			if (c.Dock == DockStyle.Fill) {
				if (!c.Bounds.IntersectsWith(want) || c.Bounds == want || want.Contains(c.Bounds)) return;
				Com.Log("fill fix: " + c.Name + " " + c.Bounds + " -> " + want);
				c.Dock = DockStyle.None;
				c.Anchor = AnchorStyles.Top | AnchorStyles.Left;
			}
			if (c.Bounds != want) c.Bounds = want;
		}
	}
}
