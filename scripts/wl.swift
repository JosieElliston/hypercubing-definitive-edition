import CoreGraphics
let l = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
for w in l { let o = (w["kCGWindowOwnerName"] as? String ?? "").lowercased(); if o.contains("mc7d") || o.contains("magictile") { print(o) } }
