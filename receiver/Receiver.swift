import AppKit
import ApplicationServices
import Darwin
import Foundation

let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
  ".local/state/flow-remote-bridge")
try FileManager.default.createDirectory(
  at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
let lockFD = open(root.appendingPathComponent("receiver.lock").path, O_CREAT | O_RDWR, 0o600)
guard lockFD >= 0, flock(lockFD, LOCK_EX | LOCK_NB) == 0 else { exit(0) }
let socketPath = root.appendingPathComponent("receiver.sock").path
struct Focus {
  let token: String
  let created: Date
  let pid: pid_t
  let element: AXUIElement
  let window: AXUIElement?
  let originalValue: String?
  let originalSelection: CFTypeRef?
}
var focuses: [String: Focus] = [:]
let journal = root.appendingPathComponent("consumed.json")
var consumed =
  (try? JSONDecoder().decode([String: Double].self, from: Data(contentsOf: journal))) ?? [:]
func attr(_ e: AXUIElement, _ name: String) -> CFTypeRef? {
  var v: CFTypeRef?
  return AXUIElementCopyAttributeValue(e, name as CFString, &v) == .success ? v : nil
}
func elementAttr(_ e: AXUIElement, _ name: String) -> AXUIElement? {
  guard let v = attr(e, name), CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
  return (v as! AXUIElement)
}
func focused() -> (pid_t, AXUIElement, AXUIElement?)? {
  guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
  let ax = AXUIElementCreateApplication(app.processIdentifier)
  guard let el = elementAttr(ax, kAXFocusedUIElementAttribute) else { return nil }
  return (app.processIdentifier, el, elementAttr(ax, kAXFocusedWindowAttribute))
}
func locked() -> Bool {
  let d = CGSessionCopyCurrentDictionary() as? [String: Any]
  return d == nil || (d?["CGSSessionScreenIsLocked"] as? Bool ?? false)
}
func result(_ status: String, _ extra: [String: Any] = [:]) -> [String: Any] {
  var r = extra
  r["status"] = status
  return r
}
func process(_ r: [String: Any]) -> [String: Any] {
  guard let client = r["client"] as? String,
    client.range(of: "^[a-zA-Z0-9_-]{1,64}$", options: .regularExpression) != nil
  else { return result("invalid-client") }
  if r["op"] as? String == "health" {
    return result("ok", ["accessibility": AXIsProcessTrusted(), "locked": locked()])
  }
  guard AXIsProcessTrusted() else { return result("needs-accessibility") }
  guard !locked() else { return result("screen-locked") }
  guard let id = r["id"] as? String, UUID(uuidString: id) != nil else {
    return result("invalid-id")
  }
  let key = client + ":" + id
  if consumed[key] != nil { return result("already-consumed") }
  guard let (pid, el, win) = focused() else { return result("no-focused-element") }
  if r["op"] as? String == "arm" {
    let token = UUID().uuidString
    focuses[key] = Focus(
      token: token, created: Date(), pid: pid, element: el, window: win,
      originalValue: attr(el, kAXValueAttribute) as? String,
      originalSelection: attr(el, kAXSelectedTextRangeAttribute))
    focuses = focuses.filter { Date().timeIntervalSince($0.value.created) < 1800 }
    return result("armed", ["token": token])
  }
  guard r["op"] as? String == "paste", let f = focuses.removeValue(forKey: key),
    r["token"] as? String == f.token
  else { return result("not-armed") }
  guard Date().timeIntervalSince(f.created) < 1800, f.pid == pid, CFEqual(f.element, el),
    f.window == nil || (win != nil && CFEqual(f.window!, win!))
  else { return result("focus-changed") }
  guard let text = r["text"] as? String, !text.isEmpty, text.utf8.count <= 65536,
    !text.contains("\0")
  else { return result("invalid-text") }
  if let sub = attr(el, kAXSubroleAttribute) as? String, sub == kAXSecureTextFieldSubrole {
    return result("secure-field")
  }
  if let enabled = attr(el, kAXEnabledAttribute) as? Bool, !enabled {
    return result("disabled-field")
  }
  // Suppress a duplicate if Flow/Parsec already inserted the same suffix.
  if let value = attr(el, kAXValueAttribute) as? String {
    var range = CFRange()
    if let av = attr(el, kAXSelectedTextRangeAttribute), CFGetTypeID(av) == AXValueGetTypeID(),
      AXValueGetValue((av as! AXValue), .cfRange, &range), range.length == 0, range.location >= 0,
      range.location <= (value as NSString).length
    {
      let prefix = (value as NSString).substring(to: range.location)
      if prefix.hasSuffix(text) {
        consumed[key] = Date().timeIntervalSince1970
        try? JSONEncoder().encode(consumed).write(to: journal, options: .atomic)
        return result("already-inserted")
      }
    }
  }
  if let original = f.originalValue, let current = attr(el, kAXValueAttribute) as? String,
    original != current
  {
    return result("field-edited")
  }
  if let original = f.originalSelection, let current = attr(el, kAXSelectedTextRangeAttribute),
    !CFEqual(original, current)
  {
    return result("selection-changed")
  }
  // Journal before emitting input: uncertain delivery is never automatically replayed.
  consumed[key] = Date().timeIntervalSince1970
  consumed = consumed.filter { Date().timeIntervalSince1970 - $0.value < 604800 }
  do { try JSONEncoder().encode(consumed).write(to: journal, options: .atomic) } catch {
    return result("journal-failed")
  }
  guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true),
    let up = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false)
  else { return result("event-failed") }
  let pb = NSPasteboard.general
  let old =
    pb.pasteboardItems?.map { item -> [NSPasteboard.PasteboardType: Data] in
      var d: [NSPasteboard.PasteboardType: Data] = [:]
      for t in item.types { if let data = item.data(forType: t) { d[t] = data } }
      return d
    } ?? []
  pb.clearContents()
  pb.setString(text, forType: .string)
  let count = pb.changeCount
  down.flags = .maskCommand
  up.flags = .maskCommand
  down.post(tap: .cghidEventTap)
  up.post(tap: .cghidEventTap)
  DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
    if pb.changeCount == count {
      pb.clearContents()
      let items = old.map { d -> NSPasteboardItem in
        let i = NSPasteboardItem()
        for (t, data) in d { i.setData(data, forType: t) }
        return i
      }
      pb.writeObjects(items)
    }
  }
  return result("paste-sent")
}
signal(SIGPIPE, SIG_IGN)
let fd = socket(AF_UNIX, SOCK_STREAM, 0)
guard fd >= 0 else { fatalError("socket failed") }
unlink(socketPath)
var addr = sockaddr_un()
addr.sun_family = sa_family_t(AF_UNIX)
let bytes = Array(socketPath.utf8) + [0]
guard bytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
  fatalError("Home path too long for Unix socket")
}
withUnsafeMutableBytes(of: &addr.sun_path) { buf in for (i, b) in bytes.enumerated() { buf[i] = b }
}
addr.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
let bound = withUnsafePointer(to: &addr) { p in
  p.withMemoryRebound(to: sockaddr.self, capacity: 1) {
    bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
  }
}
guard bound == 0, listen(fd, 8) == 0 else { fatalError("bind failed") }
chmod(socketPath, 0o600)
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
DispatchQueue.global().async {
  while true {
    let c = accept(fd, nil, nil)
    if c < 0 { continue }
    var timeout = timeval(tv_sec: 5, tv_usec: 0)
    setsockopt(c, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
    var data = Data()
    var buf = [UInt8](repeating: 0, count: 4096)
    while data.count <= 524288 {
      let n = read(c, &buf, buf.count)
      if n <= 0 { break }
      data.append(contentsOf: buf.prefix(n))
      if data.last == 10 { break }
    }
    var reply: [String: Any] = ["status": "invalid-request"]
    if data.count <= 524288,
      let r = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    {
      DispatchQueue.main.sync { reply = process(r) }
    }
    if let out = try? JSONSerialization.data(withJSONObject: reply) {
      out.withUnsafeBytes { p in _ = write(c, p.baseAddress, out.count) }
    }
    close(c)
  }
}
app.run()
