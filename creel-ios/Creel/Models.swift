import CryptoKit
import Foundation

struct Fix: Codable, Equatable {
  var latitude: Double
  var longitude: Double
  var accuracyMeters: Double
  var measuredAt: Date
}
struct TextRevision: Codable {
  var text: String
  var savedAt: Date
}
struct Attachment: Codable, Identifiable {
  var id: UUID = UUID()
  var path: String
  var mimeType: String
  var byteLength: Int
  var sha256: String
  var capturedAt: Date = Date()
  var duration: Double?
  var origin: String
}
enum MomentKind: String, Codable, CaseIterable {
  case unclassified, catchFish, observation, contextChange, journal
  var label: String {
    switch self {
    case .unclassified: "Leave it"
    case .catchFish: "Catch"
    case .observation: "Something I saw"
    case .contextChange: "Changed something"
    case .journal: "Journal / debrief"
    }
  }
  var symbol: String {
    switch self {
    case .unclassified: "leaf"
    case .catchFish: "fish"
    case .observation: "binoculars"
    case .contextChange: "arrow.triangle.swap"
    case .journal: "book"
    }
  }
}
struct MomentCorrection: Codable {
  var revision: Int
  var replacedAt: Date
  var kind: MomentKind
  var occurredAt: Date?
  var occurredUntil: Date?
  var occurrenceBasis: String
  var eventLocation: Fix?
  var deleted: Bool
}
struct TripCorrection: Codable {
  var revision: Int
  var replacedAt: Date
  var title: String
  var waterbody: String
  var companions: String
  var startedAt: Date
  var endedAt: Date?
  var outcome: String
}
struct Moment: Codable, Identifiable {
  enum CodingKeys: String, CodingKey {
    case id
    case tripID = "tripId"
    case revision, kind, capturedAt, updatedAt, occurredAt, occurredUntil
    case occurrenceBasis, captureLocation, eventLocation, textHistory, attachments, deleted,
      correctionHistory
  }
  var correctionHistory: [MomentCorrection]? = nil
  var id: UUID = UUID()
  var tripID: UUID
  var revision = 1
  var kind: MomentKind = .unclassified
  var capturedAt = Date()
  var updatedAt = Date()
  var occurredAt: Date? = Date()
  var occurredUntil: Date?
  var occurrenceBasis = "capture_time"
  var captureLocation: Fix?
  var eventLocation: Fix?
  var textHistory: [TextRevision] = []
  var attachments: [Attachment] = []
  var deleted = false
  var text: String { textHistory.last?.text ?? "" }
}
struct Trip: Codable, Identifiable {
  var correctionHistory: [TripCorrection]? = nil
  var id = UUID()
  var revision = 1
  var title: String
  var waterbody: String
  var companions: String
  var createdAt = Date()
  var startedAt = Date()
  var endedAt: Date?
  var timezone = TimeZone.current.identifier
  var outcome = "unspecified"
  var moments: [Moment] = []
  var lastExportedRevision: Int?
  var name: String {
    !title.isEmpty ? title : (!waterbody.isEmpty ? waterbody : "A day on the water")
  }
  var visible: [Moment] {
    moments.filter { !$0.deleted }.sorted {
      ($0.occurredAt ?? $0.capturedAt) < ($1.occurredAt ?? $1.capturedAt)
    }
  }
}
struct Library: Codable { var trips: [Trip] = [] }
enum CreelError: LocalizedError {
  case message(String)
  var errorDescription: String? {
    if case .message(let s) = self { return s }
    return nil
  }
}
func digest(_ data: Data) -> String {
  SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}
func encoder() -> JSONEncoder {
  let e = JSONEncoder()
  e.dateEncodingStrategy = .iso8601
  e.keyEncodingStrategy = .convertToSnakeCase
  e.outputFormatting = [.prettyPrinted, .sortedKeys]
  return e
}
func decoder() -> JSONDecoder {
  let d = JSONDecoder()
  d.dateDecodingStrategy = .iso8601
  d.keyDecodingStrategy = .convertFromSnakeCase
  return d
}

// Atomic metadata commits. Media is written first, so a failed commit never references missing bytes.
final class Repository {
  let root: URL
  init(unavailableRoot: URL) { self.root = unavailableRoot }
  init(root: URL) throws {
    self.root = root
    try FileManager.default.createDirectory(
      at: root.appendingPathComponent("media"), withIntermediateDirectories: true)
  }
  func load() throws -> Library {
    let url = root.appendingPathComponent("library.json")
    guard FileManager.default.fileExists(atPath: url.path) else { return Library() }
    return try decoder().decode(Library.self, from: Data(contentsOf: url))
  }
  func save(_ library: Library) throws {
    try encoder().encode(library).write(
      to: root.appendingPathComponent("library.json"), options: .atomic)
  }
  func media(_ data: Data, ext: String, mime: String, origin: String, duration: Double? = nil)
    throws -> Attachment
  {
    guard !data.isEmpty else { throw CreelError.message("The file was empty. Nothing was saved.") }
    let id = UUID()
    let path = "media/\(id.uuidString).\(ext)"
    try data.write(to: root.appendingPathComponent(path), options: .atomic)
    return Attachment(
      id: id, path: path, mimeType: mime, byteLength: data.count, sha256: digest(data),
      duration: duration, origin: origin)
  }
  func export(_ trip: Trip) throws -> URL {
    struct FileEntry: Codable {
      let path: String
      let byteLength: Int
      let mimeType: String
      let sha256: String
    }
    struct Manifest: Encodable {
      let schemaVersion = "1.0"
      let packageID = UUID()
      let exportedAt = Date()
      let appVersion = "0.1"
      let tripID: UUID
      let tripRevision: Int
      let files: [FileEntry]
    }
    let dir = root.appendingPathComponent("exports/\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    var complete = false
    defer { if !complete { try? FileManager.default.removeItem(at: dir) } }
    var metadata = trip
    metadata.moments = []
    metadata.lastExportedRevision = nil
    let metadataFiles = [
      ("trip.json", try encoder().encode(metadata)),
      ("events.json", try encoder().encode(trip.moments)),
    ]
    var files: [(String, URL)] = []
    var entries: [FileEntry] = []
    var total = 0
    for (name, bytes) in metadataFiles {
      let file = dir.appendingPathComponent(name)
      try bytes.write(to: file, options: .atomic)
      files.append((name, file))
      entries.append(
        FileEntry(
          path: name, byteLength: bytes.count, mimeType: "application/json", sha256: digest(bytes)))
      total += bytes.count
    }
    var seen = Set<String>()
    for attachment in trip.moments.flatMap(\.attachments) {
      guard attachment.path.hasPrefix("media/"), !attachment.path.contains(".."),
        attachment.path.split(separator: "/").count == 2, seen.insert(attachment.path).inserted
      else {
        throw CreelError.message("An original has an invalid or duplicate path. Export stopped.")
      }
      let file = root.appendingPathComponent(attachment.path)
      let bytes = try Data(contentsOf: file, options: .mappedIfSafe)
      guard bytes.count == attachment.byteLength, digest(bytes) == attachment.sha256 else {
        throw CreelError.message(
          "An original file did not pass its integrity check. Export stopped; your trip is still here."
        )
      }
      total += bytes.count
      guard total <= 250 * 1024 * 1024 else {
        throw CreelError.message(
          "This trip exceeds the current 250 MB export limit. Your originals remain on this phone.")
      }
      files.append((attachment.path, file))
      entries.append(
        FileEntry(
          path: attachment.path, byteLength: bytes.count, mimeType: attachment.mimeType,
          sha256: attachment.sha256))
    }
    let manifest = Manifest(tripID: trip.id, tripRevision: trip.revision, files: entries)
    let manifestURL = dir.appendingPathComponent("manifest.json")
    try encoder().encode(manifest).write(to: manifestURL, options: .atomic)
    files.append(("manifest.json", manifestURL))
    let url = dir.appendingPathComponent("Creel-\(trip.id.uuidString.prefix(8)).fishing-trip.zip")
    try StoredZip.write(files, to: url)
    for (name, _) in metadataFiles {
      try? FileManager.default.removeItem(at: dir.appendingPathComponent(name))
    }
    try? FileManager.default.removeItem(at: manifestURL)
    complete = true
    return url
  }
}
// Standard uncompressed ZIP: no network dependency, original bytes unchanged.
enum StoredZip {
  // Stream each source into the archive; memory does not scale with the whole trip.
  static func write(_ files: [(String, URL)], to url: URL) throws {
    guard files.count < 65535 else { throw CreelError.message("Too many files in this trip.") }
    guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
      throw CreelError.message("Unable to create the trip package.")
    }
    let output = try FileHandle(forWritingTo: url)
    defer { try? output.close() }
    var central = Data()
    var offset: UInt32 = 0
    for (path, source) in files {
      let bytes = try Data(contentsOf: source, options: .mappedIfSafe)
      guard bytes.count < Int(UInt32.max), path.utf8.count < 65535 else {
        throw CreelError.message("File too large for this package format.")
      }
      let name = Data(path.utf8)
      let size = UInt32(bytes.count)
      let crc = crc32(bytes)
      var header = Data()
      header.le(UInt32(0x0403_4b50))
      header.le(UInt16(20))
      header.le(UInt16(0x800))
      header.le(UInt16(0))
      header.le(UInt16(0))
      header.le(UInt16(33))
      header.le(crc)
      header.le(size)
      header.le(size)
      header.le(UInt16(name.count))
      header.le(UInt16(0))
      header.append(name)
      try output.write(contentsOf: header)
      let input = try FileHandle(forReadingFrom: source)
      do {
        while let chunk = try input.read(upToCount: 1024 * 1024), !chunk.isEmpty {
          try output.write(contentsOf: chunk)
        }
        try input.close()
      } catch {
        try? input.close()
        throw error
      }
      central.le(UInt32(0x0201_4b50))
      central.le(UInt16(20))
      central.le(UInt16(20))
      central.le(UInt16(0x800))
      central.le(UInt16(0))
      central.le(UInt16(0))
      central.le(UInt16(33))
      central.le(crc)
      central.le(size)
      central.le(size)
      central.le(UInt16(name.count))
      central.le(UInt16(0))
      central.le(UInt16(0))
      central.le(UInt16(0))
      central.le(UInt16(0))
      central.le(UInt32(0))
      central.le(offset)
      central.append(name)
      offset += UInt32(header.count) + size
    }
    var tail = Data()
    tail.le(UInt32(0x0605_4b50))
    tail.le(UInt16(0))
    tail.le(UInt16(0))
    tail.le(UInt16(files.count))
    tail.le(UInt16(files.count))
    tail.le(UInt32(central.count))
    tail.le(offset)
    tail.le(UInt16(0))
    try output.write(contentsOf: central)
    try output.write(contentsOf: tail)
    try output.synchronize()
  }
  static func make(_ files: [(String, Data)]) -> Data {
    var out = Data()
    var central = Data()
    for (path, bytes) in files {
      let name = Data(path.utf8)
      let offset = UInt32(out.count)
      let size = UInt32(bytes.count)
      let crc = crc32(bytes)
      out.le(UInt32(0x0403_4b50))
      out.le(UInt16(20))
      out.le(UInt16(0x800))
      out.le(UInt16(0))
      out.le(UInt16(0))
      out.le(UInt16(33))
      out.le(crc)
      out.le(size)
      out.le(size)
      out.le(UInt16(name.count))
      out.le(UInt16(0))
      out.append(name)
      out.append(bytes)
      central.le(UInt32(0x0201_4b50))
      central.le(UInt16(20))
      central.le(UInt16(20))
      central.le(UInt16(0x800))
      central.le(UInt16(0))
      central.le(UInt16(0))
      central.le(UInt16(33))
      central.le(crc)
      central.le(size)
      central.le(size)
      central.le(UInt16(name.count))
      central.le(UInt16(0))
      central.le(UInt16(0))
      central.le(UInt16(0))
      central.le(UInt16(0))
      central.le(UInt32(0))
      central.le(offset)
      central.append(name)
    }
    let start = UInt32(out.count)
    out.append(central)
    out.le(UInt32(0x0605_4b50))
    out.le(UInt16(0))
    out.le(UInt16(0))
    out.le(UInt16(files.count))
    out.le(UInt16(files.count))
    out.le(UInt32(central.count))
    out.le(start)
    out.le(UInt16(0))
    return out
  }
  static func crc32(_ data: Data) -> UInt32 {
    var c: UInt32 = 0xffff_ffff
    for b in data {
      c ^= UInt32(b)
      for _ in 0..<8 { c = (c >> 1) ^ ((c & 1) != 0 ? 0xedb8_8320 : 0) }
    }
    return c ^ 0xffff_ffff
  }
}
extension Data {
  mutating func le<T: FixedWidthInteger>(_ value: T) {
    var v = value.littleEndian
    Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
  }
}
