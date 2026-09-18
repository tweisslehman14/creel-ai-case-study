import XCTest
@testable import CreelCore

final class RepositoryTests: XCTestCase {
    var directory: URL!
    var repository: Repository!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("CreelTests-\(UUID())")
        repository = try Repository(root: directory)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }
    func sampleTrip() -> Trip {
        var trip = Trip(title: "Evening", waterbody: "Madison", companions: "")
        var moment = Moment(tripID: trip.id)
        moment.textHistory = [TextRevision(text: "Elk hair caddis", savedAt: Date()), TextRevision(text: "Size 16 elk hair caddis", savedAt: Date())]
        moment.captureLocation = Fix(latitude: 45.1, longitude: -111.4, accuracyMeters: 15, measuredAt: Date())
        moment.occurredAt = nil
        moment.occurrenceBasis = "unknown"
        trip.moments = [moment]
        return trip
    }
    func testPersistenceRoundTripRetainsIdentityHistoryAndUnknownTime() throws {
        let trip = sampleTrip()
        try repository.save(Library(trips: [trip]))
        let loaded = try Repository(root: directory).load()
        let restored = try XCTUnwrap(loaded.trips.first)
        XCTAssertEqual(restored.id, trip.id)
        XCTAssertEqual(restored.moments.first?.tripID, trip.id)
        XCTAssertEqual(restored.moments.first?.id, trip.moments.first?.id)
        XCTAssertEqual(restored.moments.first?.textHistory.count, 2)
        XCTAssertEqual(restored.moments.first?.text, "Size 16 elk hair caddis")
        XCTAssertNil(restored.moments.first?.occurredAt)
        XCTAssertEqual(restored.moments.first?.captureLocation?.latitude, 45.1)
    }
    func testExportIsStandardZIPPreservingOriginalBytesAndManifestChecksums() throws {
        let original = Data((0..<4096).map { UInt8($0 % 256) })
        let attachment = try repository.media(original, ext: "jpg", mime: "image/jpeg", origin: "test")
        var trip = sampleTrip(); trip.moments[0].attachments = [attachment]
        let archive = try repository.export(trip)
        let extracted = directory.appendingPathComponent("extracted")
        let unzip = Process(); unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip"); unzip.arguments = ["-q", archive.path, "-d", extracted.path]
        try unzip.run(); unzip.waitUntilExit(); XCTAssertEqual(unzip.terminationStatus, 0)
        XCTAssertEqual(try Data(contentsOf: extracted.appendingPathComponent(attachment.path)), original)
        let manifest = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: extracted.appendingPathComponent("manifest.json"))) as? [String: Any])
        let files = try XCTUnwrap(manifest["files"] as? [[String: Any]])
        XCTAssertEqual(files.count, 3)
        for file in files {
            let path = try XCTUnwrap(file["path"] as? String)
            let bytes = try Data(contentsOf: extracted.appendingPathComponent(path))
            XCTAssertEqual(file["sha256"] as? String, digest(bytes))
            XCTAssertEqual(file["byte_length"] as? Int, bytes.count)
        }
        let events = try decoder().decode([Moment].self, from: Data(contentsOf: extracted.appendingPathComponent("events.json")))
        XCTAssertEqual(events.first?.tripID, trip.id)
    }
    func testCorruptedOriginalStopsExportWithoutChangingLibrary() throws {
        var trip = sampleTrip()
        let attachment = try repository.media(Data("original".utf8), ext: "m4a", mime: "audio/mp4", origin: "test")
        trip.moments[0].attachments = [attachment]
        try repository.save(Library(trips: [trip]))
        try Data("modified".utf8).write(to: directory.appendingPathComponent(attachment.path))
        XCTAssertThrowsError(try repository.export(trip))
        XCTAssertEqual(try repository.load().trips.first?.id, trip.id)
    }
    func testEmptyAttachmentIsRejected() { XCTAssertThrowsError(try repository.media(Data(), ext: "jpg", mime: "image/jpeg", origin: "test")) }
    func testCorruptLibraryIsNotSilentlyReplaced() throws {
        let path = directory.appendingPathComponent("library.json")
        let bytes = Data("not valid JSON".utf8); try bytes.write(to: path)
        XCTAssertThrowsError(try repository.load())
        XCTAssertEqual(try Data(contentsOf: path), bytes)
    }
    func testInvalidAndDuplicateExportPathsAreRejectedAndPartialExportsRemoved() throws {
        let attachment = try repository.media(Data("photo".utf8), ext: "jpg", mime: "image/jpeg", origin: "test")
        for path in ["../outside.jpg", "media/../outside.jpg", "media/nested/photo.jpg", "/media/photo.jpg"] {
            var invalid = attachment; invalid.path = path
            var trip = sampleTrip(); trip.moments[0].attachments = [invalid]
            XCTAssertThrowsError(try repository.export(trip)) { error in
                XCTAssertTrue(error.localizedDescription.contains("invalid or duplicate path"))
            }
        }
        var trip = sampleTrip(); trip.moments[0].attachments = [attachment, attachment]
        XCTAssertThrowsError(try repository.export(trip)) { error in
            XCTAssertTrue(error.localizedDescription.contains("invalid or duplicate path"))
        }
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: directory.appendingPathComponent("exports").path).isEmpty)
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent(attachment.path)), Data("photo".utf8))
    }
    func testOversizedExportIsRejectedAndOriginalRetained() throws {
        let length = 250 * 1024 * 1024 + 1
        let path = "media/large.m4a", file = directory.appendingPathComponent("media/large.m4a")
        XCTAssertTrue(FileManager.default.createFile(atPath: file.path, contents: nil))
        let handle = try FileHandle(forWritingTo: file)
        try handle.truncate(atOffset: UInt64(length)); try handle.close()
        let checksum = try digest(Data(contentsOf: file, options: .alwaysMapped))
        let attachment = Attachment(path: path, mimeType: "audio/mp4", byteLength: length, sha256: checksum, origin: "test")
        var trip = sampleTrip(); trip.moments[0].attachments = [attachment]
        XCTAssertThrowsError(try repository.export(trip)) { error in
            XCTAssertTrue(error.localizedDescription.contains("250 MB export limit"))
        }
        XCTAssertEqual((try FileManager.default.attributesOfItem(atPath: file.path)[.size] as? NSNumber)?.intValue, length)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: directory.appendingPathComponent("exports").path).isEmpty)
    }
    func testTripAndMomentCorrectionHistoryRoundTripsWithoutReplacingCurrentValues() throws {
        let earlier = Date(timeIntervalSince1970: 1_700_000_000)
        let fix = Fix(latitude: 45.2, longitude: -111.6, accuracyMeters: 21, measuredAt: earlier)
        var trip = sampleTrip(); trip.revision = 4
        trip.correctionHistory = [TripCorrection(revision: 2, replacedAt: earlier, title: "Morning", waterbody: "Unknown", companions: "Pat", startedAt: earlier, endedAt: earlier.addingTimeInterval(3600), outcome: "zero")]
        trip.moments[0].revision = 3
        trip.moments[0].correctionHistory = [MomentCorrection(revision: 1, replacedAt: earlier, kind: .observation, occurredAt: earlier, occurredUntil: earlier.addingTimeInterval(60), occurrenceBasis: "range", eventLocation: fix, deleted: false)]
        try repository.save(Library(trips: [trip]))
        let restored = try XCTUnwrap(repository.load().trips.first)
        let oldTrip = try XCTUnwrap(restored.correctionHistory?.first)
        XCTAssertEqual(oldTrip.title, "Morning"); XCTAssertEqual(oldTrip.waterbody, "Unknown")
        XCTAssertEqual(oldTrip.companions, "Pat"); XCTAssertEqual(oldTrip.outcome, "zero")
        XCTAssertEqual(oldTrip.endedAt, earlier.addingTimeInterval(3600)); XCTAssertEqual(oldTrip.revision, 2)
        XCTAssertEqual(restored.title, "Evening"); XCTAssertEqual(restored.revision, 4)
        let moment = try XCTUnwrap(restored.moments.first)
        let oldMoment = try XCTUnwrap(moment.correctionHistory?.first)
        XCTAssertEqual(oldMoment.kind, .observation); XCTAssertEqual(oldMoment.occurrenceBasis, "range")
        XCTAssertEqual(oldMoment.occurredUntil, earlier.addingTimeInterval(60)); XCTAssertEqual(oldMoment.eventLocation, fix)
        XCTAssertEqual(moment.kind, .unclassified); XCTAssertNil(moment.occurredAt); XCTAssertEqual(moment.revision, 3)
    }

}
