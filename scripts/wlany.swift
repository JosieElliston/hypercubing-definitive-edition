import CoreGraphics
let l = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as! [[String: Any]]
for w in l { let o = "\(w["kCGWindowOwnerName"] ?? "")"; let n = "\(w["kCGWindowName"] ?? "")"; let b = w["kCGWindowBounds"] as? [String: Any] ?? [:]
  if CommandLine.arguments.count < 2 || o.lowercased().contains(CommandLine.arguments[1].lowercased()) { print(o, "|", n, "|", w["kCGWindowLayer"] ?? "", "|", b["Width"] ?? "", "x", b["Height"] ?? "", "| onscreen:", w["kCGWindowIsOnscreen"] ?? 0) } }
