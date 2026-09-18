import AVFoundation
import CoreLocation
import SwiftUI

@MainActor final class Journal: ObservableObject {
  @Published var library = Library()
  @Published var error: String?
  @Published var ready = false
  let repo: Repository
  init() {
    let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Creel")
    do { repo = try Repository(root: root) } catch {
      repo = Repository(unavailableRoot: root)
      self.error =
        "Local storage could not be opened. No captures can be saved until storage is available. \(error.localizedDescription)"
      return
    }
    do {
      library = try repo.load()
      ready = true
    } catch {
      self.error =
        "Your saved library could not be read. It has not been overwritten. \(error.localizedDescription)"
    }
    recoverAudio()
  }
  @discardableResult func commit(_ change: (inout Library) -> Void) -> Bool {
    guard ready else {
      error = "The library is unavailable. Existing files have been left untouched."
      return false
    }
    var next = library
    change(&next)
    do {
      try repo.save(next)
      library = next
      return true
    } catch {
      self.error = "Not saved. Keep this screen open and try again. \(error.localizedDescription)"
      return false
    }
  }
  func trip(_ id: UUID) -> Trip? { library.trips.first { $0.id == id } }
  @discardableResult func update(_ id: UUID, _ change: (inout Trip) -> Void) -> Bool {
    guard trip(id) != nil else {
      error = "This trip is unavailable. Nothing was saved."
      return false
    }
    return commit { lib in
      guard let i = lib.trips.firstIndex(where: { $0.id == id }) else { return }
      let before = lib.trips[i]
      change(&lib.trips[i])
      lib.trips[i].revision += 1
      if before.title != lib.trips[i].title || before.waterbody != lib.trips[i].waterbody
        || before.companions != lib.trips[i].companions
        || before.startedAt != lib.trips[i].startedAt || before.endedAt != lib.trips[i].endedAt
        || before.outcome != lib.trips[i].outcome
      {
        lib.trips[i].correctionHistory =
          (before.correctionHistory ?? []) + [
            TripCorrection(
              revision: before.revision, replacedAt: Date(), title: before.title,
              waterbody: before.waterbody, companions: before.companions,
              startedAt: before.startedAt, endedAt: before.endedAt, outcome: before.outcome)
          ]
      }
    }
  }
  @discardableResult func edit(_ tripID: UUID, _ eventID: UUID, _ change: (inout Moment) -> Void)
    -> Bool
  {
    guard trip(tripID)?.moments.contains(where: { $0.id == eventID }) == true else {
      error = "This moment is unavailable. Nothing was saved."
      return false
    }
    return update(tripID) { trip in
      guard let i = trip.moments.firstIndex(where: { $0.id == eventID }) else { return }
      let before = trip.moments[i]
      change(&trip.moments[i])
      trip.moments[i].revision += 1
      trip.moments[i].updatedAt = Date()
      if before.kind != trip.moments[i].kind || before.occurredAt != trip.moments[i].occurredAt
        || before.occurredUntil != trip.moments[i].occurredUntil
        || before.occurrenceBasis != trip.moments[i].occurrenceBasis
        || before.eventLocation != trip.moments[i].eventLocation
        || before.deleted != trip.moments[i].deleted
      {
        trip.moments[i].correctionHistory =
          (before.correctionHistory ?? []) + [
            MomentCorrection(
              revision: before.revision, replacedAt: Date(), kind: before.kind,
              occurredAt: before.occurredAt, occurredUntil: before.occurredUntil,
              occurrenceBasis: before.occurrenceBasis, eventLocation: before.eventLocation,
              deleted: before.deleted)
          ]
      }
    }
  }
  func add(
    trip: UUID, text: String = "", attachment: Attachment? = nil, fix: Fix? = nil,
    existing: UUID? = nil, immediate: Bool = true
  ) -> UUID? {
    if let existing {
      let ok = edit(trip, existing) { e in
        if !text.isEmpty { e.textHistory.append(TextRevision(text: text, savedAt: Date())) }
        if let attachment { e.attachments.append(attachment) }
      }
      return ok ? existing : nil
    }
    var event = Moment(tripID: trip)
    event.occurredAt = immediate ? event.capturedAt : nil
    event.occurrenceBasis = immediate ? "capture_time" : "unknown"
    event.captureLocation = fix
    event.eventLocation = immediate ? fix : nil
    if !text.isEmpty { event.textHistory = [TextRevision(text: text, savedAt: Date())] }
    if let attachment { event.attachments = [attachment] }
    return update(trip) { $0.moments.append(event) } ? event.id : nil
  }
  struct Pending: Codable {
    enum CodingKeys: String, CodingKey {
      case tripID = "tripId"
      case eventID = "eventId"
      case file, capturedAt, fix
    }
    var tripID: UUID
    var eventID: UUID
    var file: String
    var capturedAt: Date
    var fix: Fix?
  }
  var pendingURL: URL { repo.root.appendingPathComponent("recording-pending.json") }
  func recoverAudio() {
    guard ready, FileManager.default.fileExists(atPath: pendingURL.path) else { return }
    do {
      let p = try decoder().decode(Pending.self, from: Data(contentsOf: pendingURL))
      let url = repo.root.appendingPathComponent(p.file)
      guard trip(p.tripID)?.moments.contains(where: { $0.id == p.eventID }) == true else {
        throw CreelError.message("The recording’s trip is missing.")
      }
      // A finalized chunk may have committed just before a crash. Do not attach it twice.
      if trip(p.tripID)?.moments.first(where: { $0.id == p.eventID })?.attachments.contains(where: {
        $0.origin == p.file
      }) == true {
        try FileManager.default.removeItem(at: pendingURL)
        try? FileManager.default.removeItem(at: url)
        return
      }
      let player = try AVAudioPlayer(contentsOf: url)
      var a = try repo.media(
        Data(contentsOf: url), ext: "m4a", mime: "audio/mp4", origin: p.file,
        duration: player.duration)
      a.capturedAt = p.capturedAt
      if edit(p.tripID, p.eventID, { $0.attachments.append(a) }) {
        try FileManager.default.removeItem(at: pendingURL)
        try? FileManager.default.removeItem(at: url)
        error =
          "An interrupted audio part was recovered. You can play it in your trip and add another part."
      }
    } catch {
      let detail = error.localizedDescription
      do {
        // Preserve both the raw file and its association; free the active journal for the next capture.
        let archived = repo.root.appendingPathComponent("unrecovered-\(UUID().uuidString).json")
        try FileManager.default.moveItem(at: pendingURL, to: archived)
        self.error =
          "The unfinished audio part could not be recovered. Earlier completed parts remain in your trip. The unfinished original is retained separately on this phone, outside the trip export. You can record a new part. \(detail)"
      } catch {
        self.error =
          "An unfinished recording needs recovery before another recording can start. Its original is retained. Typing and photos still work. \(detail)"
      }
    }
  }
}

@MainActor
final class Position: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
  @Published var fix: Fix?
  @Published var status = "Location not requested"
  private let manager = CLLocationManager()
  override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
  }
  func request() {
    manager.requestWhenInUseAuthorization()
    if manager.authorizationStatus == .authorizedWhenInUse
      || manager.authorizationStatus == .authorizedAlways
    {
      manager.requestLocation()
    }
  }
  func current() -> Fix? {
    guard let fix, abs(fix.measuredAt.timeIntervalSinceNow) < 60 else { return nil }
    return fix
  }
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    switch manager.authorizationStatus {
    case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
    case .denied, .restricted: status = "Location unavailable · capture still works"
    default: break
    }
  }
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last, location.horizontalAccuracy >= 0,
      abs(location.timestamp.timeIntervalSinceNow) < 60
    else {
      status = "No recent location fix"
      return
    }
    fix = Fix(
      latitude: location.coordinate.latitude, longitude: location.coordinate.longitude,
      accuracyMeters: location.horizontalAccuracy, measuredAt: location.timestamp)
    status = "Location available · ±\(Int(location.horizontalAccuracy)) m"
  }
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    status = "Location unknown · capture still works"
  }
}

@MainActor final class VoiceRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
  @Published var recording = false
  @Published var elapsed: TimeInterval = 0
  @Published var message = ""
  @Published var eventID: UUID?
  private var recorder: AVAudioRecorder?
  private var timer: Timer?
  private var started = Date()
  private var chunkStarted = Date()
  private var previousIdleTimerDisabled: Bool?
  private var starting = false
  private weak var journal: Journal?
  private var pending: Journal.Pending?
  override init() {
    super.init()
    NotificationCenter.default.addObserver(
      self, selector: #selector(interrupted), name: AVAudioSession.interruptionNotification,
      object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(backgrounded), name: UIApplication.didEnterBackgroundNotification,
      object: nil)
  }
  func start(
    journal: Journal, trip: UUID, existing: UUID?, fix: Fix?,
    initialKind: MomentKind = .unclassified
  ) async {
    guard journal.ready else {
      message = "Local storage is unavailable. Recording cannot start."
      return
    }
    guard !recording, !starting else { return }
    starting = true
    defer { starting = false }
    let allowed = await AVAudioApplication.requestRecordPermission()
    guard UIApplication.shared.applicationState == .active else {
      message = "Keep Creel open to begin recording."
      return
    }
    guard allowed else {
      message = "Microphone access is off. You can type a note or enable Microphone in Settings."
      return
    }
    guard !FileManager.default.fileExists(atPath: journal.pendingURL.path) else {
      message =
        "An interrupted recording needs recovery. Restart the app to retry before recording again. You can still type or add photos."
      return
    }
    self.journal = journal
    let id: UUID
    if let existing {
      guard journal.trip(trip)?.moments.contains(where: { $0.id == existing }) == true else {
        message = "This moment is unavailable."
        return
      }
      id = existing
    } else {
      var event = Moment(tripID: trip)
      event.kind = initialKind
      event.occurredAt = event.capturedAt
      event.captureLocation = fix
      event.eventLocation = fix
      guard journal.update(trip, { $0.moments.append(event) }) else { return }
      id = event.id
    }
    eventID = id
    started = Date()
    elapsed = 0
    do {
      try AVAudioSession.sharedInstance().setCategory(.record, mode: .default)
      try AVAudioSession.sharedInstance().setActive(true)
      try beginChunk(trip: trip, event: id, fix: fix)
      previousIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
      UIApplication.shared.isIdleTimerDisabled = true
      recording = true
      message = "Recording on this phone"
      timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
        Task { @MainActor in self?.tick() }
      }
    } catch {
      recorder?.stop()
      try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
      if let pending,
        !FileManager.default.fileExists(
          atPath: journal.repo.root.appendingPathComponent(pending.file).path)
      {
        try? FileManager.default.removeItem(at: journal.pendingURL)
        self.pending = nil
      }
      restoreIdleTimer()
      message = "Recording did not start: \(error.localizedDescription)"
    }
  }
  private func beginChunk(trip: UUID, event: UUID, fix: Fix?) throws {
    guard let journal else { throw CreelError.message("The trip storage is unavailable.") }
    let p = Journal.Pending(
      tripID: trip, eventID: event, file: "recording-\(UUID().uuidString).m4a", capturedAt: Date(),
      fix: fix)
    try encoder().encode(p).write(to: journal.pendingURL, options: .atomic)
    pending = p
    recorder = try AVAudioRecorder(
      url: journal.repo.root.appendingPathComponent(p.file),
      settings: [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
      ])
    recorder?.delegate = self
    guard recorder?.record() == true else {
      throw CreelError.message("The microphone could not start.")
    }
    chunkStarted = Date()
  }
  private func finishChunk() throws {
    guard let journal, let p = pending, let recorder else {
      throw CreelError.message("No active audio part could be finalized.")
    }
    let duration = recorder.currentTime
    recorder.stop()
    let url = journal.repo.root.appendingPathComponent(p.file)
    var attachment = try journal.repo.media(
      Data(contentsOf: url), ext: "m4a", mime: "audio/mp4", origin: p.file, duration: duration)
    attachment.capturedAt = p.capturedAt
    guard journal.edit(p.tripID, p.eventID, { $0.attachments.append(attachment) }) else {
      throw CreelError.message(
        "The audio file is retained for recovery, but could not be added to the trip.")
    }
    try FileManager.default.removeItem(at: journal.pendingURL)
    try? FileManager.default.removeItem(at: url)
    pending = nil
  }
  private func tick() {
    elapsed = Date().timeIntervalSince(started)
    if Date().timeIntervalSince(chunkStarted) >= 30, let p = pending {
      do {
        try finishChunk()
        try beginChunk(trip: p.tripID, event: p.eventID, fix: p.fix)
      } catch { stopWithError(error) }
    }
  }
  private func restoreIdleTimer() {
    if let previousIdleTimerDisabled {
      UIApplication.shared.isIdleTimerDisabled = previousIdleTimerDisabled
      self.previousIdleTimerDisabled = nil
    }
  }
  @discardableResult func stop() -> Bool {
    guard recording else { return false }
    timer?.invalidate()
    recording = false
    restoreIdleTimer()
    var saved = false
    do {
      try finishChunk()
      message = "Saved on this device"
      saved = true
    } catch { message = "Audio interrupted: \(error.localizedDescription)" }
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    return saved
  }
  private func stopWithError(_ error: Error) {
    timer?.invalidate()
    recorder?.stop()
    recording = false
    restoreIdleTimer()
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    message = "Recording stopped. Earlier parts are saved. \(error.localizedDescription)"
  }
  @objc private func interrupted() {
    guard recording else { return }
    if stop() {
      message =
        "Recording was interrupted. Completed parts are saved; check playback before recording a new part."
    }
  }
  @objc private func backgrounded() {
    guard recording else { return }
    if stop() {
      message =
        "Recording stopped when you left the app. Saved parts are in the trip. Keep Creel open to record."
    }
  }
  nonisolated func audioRecorderDidFinishRecording(
    _ recorder: AVAudioRecorder, successfully flag: Bool
  ) {
    if !flag {
      Task { @MainActor in
        if self.recording {
          self.stopWithError(
            CreelError.message(
              "The audio recorder stopped unexpectedly. The unfinished file is retained for recovery."
            ))
        }
      }
    }
  }
  nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
    Task { @MainActor in self.stopWithError(error ?? CreelError.message("Audio encoding failed.")) }
  }
}

@MainActor final class Playback: ObservableObject {
  @Published var playing: UUID?
  @Published var error: String?
  private var player: AVAudioPlayer?
  private var timer: Timer?
  func toggle(_ attachment: Attachment, root: URL) {
    if playing == attachment.id {
      stop()
      return
    }
    do {
      stop()
      try AVAudioSession.sharedInstance().setCategory(.playback)
      try AVAudioSession.sharedInstance().setActive(true)
      player = try AVAudioPlayer(contentsOf: root.appendingPathComponent(attachment.path))
      guard player?.play() == true else {
        throw CreelError.message("This recording cannot be played.")
      }
      playing = attachment.id
      timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
        Task { @MainActor in if self?.player?.isPlaying == false { self?.stop() } }
      }
    } catch { self.error = error.localizedDescription }
  }
  func stop() {
    player?.stop()
    playing = nil
    timer?.invalidate()
  }
}
