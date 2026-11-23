import CoreGraphics
let l = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
for w in l { print(w["kCGWindowOwnerName"] ?? "", w["kCGWindowLayer"] ?? "") }
