import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

extension Color {
  init(hex: UInt32) {
    self.init(
      .sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255,
      blue: Double(hex & 255) / 255, opacity: 1)
  }
}
enum Style {
  static let paper = Color(hex: 0xf5ead8), surface = Color(hex: 0xebddc5),
    ink = Color(hex: 0x201e1d), orange = Color(hex: 0xc67139), sage = Color(hex: 0x7a8a5e)
  static func heading(_ size: CGFloat = 30) -> Font {
    .system(size: size, weight: .bold, design: .serif)
  }
}
struct Pill: ButtonStyle {
  var primary = false
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.system(.body, design: .rounded).weight(.semibold)).frame(
      maxWidth: .infinity
    ).padding(.vertical, 17).padding(.horizontal, 12).background(
      primary ? Style.orange : Style.surface, in: Capsule()
    ).foregroundStyle(Style.ink).opacity(configuration.isPressed ? 0.65 : 1)
  }
}
extension View {
  func card() -> some View {
    padding(20).frame(maxWidth: .infinity, alignment: .leading).background(
      Style.surface, in: RoundedRectangle(cornerRadius: 24))
  }
  func canvas() -> some View {
    background(Style.paper).foregroundStyle(Style.ink).toolbarBackground(
      Style.paper, for: .navigationBar
    ).toolbarBackground(.visible, for: .navigationBar)
  }
}
struct Intro: View {
  var title: String
  var subtitle: String
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(Style.heading(34))
      Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
    }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 12)
  }
}
@main struct CreelApp: App {
  @StateObject private var journal = Journal()
  @StateObject private var position = Position()
  var body: some Scene {
    WindowGroup {
      TripList().environmentObject(journal).environmentObject(position).tint(Style.ink)
        .preferredColorScheme(.light).alert(
          "A note from Creel",
          isPresented: Binding(
            get: { journal.error != nil }, set: { if !$0 { journal.error = nil } })
        ) {
          Button("OK") { journal.error = nil }
        } message: {
          Text(journal.error ?? "")
        }
    }
  }
}
struct TripList: View {
  @EnvironmentObject var journal: Journal
  @State private var search = ""
  @State private var starting = false
  var trips: [Trip] {
    journal.library.trips.reversed().filter {
      search.isEmpty
        || ([$0.name, $0.waterbody, $0.companions] + $0.visible.map(\.text)).joined(separator: " ")
          .localizedCaseInsensitiveContains(search)
    }
  }
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          HStack {
            Label("CREEL", systemImage: "fish").font(.caption.weight(.heavy)).tracking(3)
            Spacer()
            Text("On this phone").font(.caption).padding(9).background(Style.surface, in: Capsule())
          }
          Intro(title: "Your creel", subtitle: "Nothing sent anywhere.")
          HStack {
            Image(systemName: "magnifyingglass")
            TextField("Search your trips & notes", text: $search).accessibilityIdentifier(
              "tripSearch")
          }.padding(16).background(Style.surface, in: Capsule())
          if journal.library.trips.isEmpty {
            VStack(spacing: 22) {
              Image(systemName: "fish").font(.system(size: 90)).rotationEffect(.degrees(-12))
                .foregroundStyle(Style.sage).padding(.top, 45)
              Text("No trips yet").font(Style.heading())
              Text(
                "When you get to the water, start a trip. You can leave it half-filled — a photo on its own is a perfectly good memory."
              ).multilineTextAlignment(.center).foregroundStyle(.secondary)
            }.padding(24)
          } else if trips.isEmpty {
            Text("No trips match your words yet.").card()
          }
          ForEach(trips) { trip in
            NavigationLink {
              TripScreen(id: trip.id)
            } label: {
              VStack(alignment: .leading, spacing: 12) {
                HStack {
                  Text(trip.name).font(Style.heading(24))
                  Spacer()
                  Image(systemName: "arrow.up.right")
                }
                Text(trip.startedAt.formatted(date: .abbreviated, time: .shortened)).font(
                  .subheadline)
                Text(
                  "\(trip.visible.count) moments · \(trip.endedAt == nil ? "Trip running" : "Trip ended")"
                )
                if trip.outcome == "zero_catches" { Text("No fish — said so").font(.caption) }
                Text(
                  trip.lastExportedRevision == trip.revision
                    ? "Package created · kept here too"
                    : (trip.lastExportedRevision == nil
                      ? "Not exported yet" : "Changes since last export")
                ).font(.caption).foregroundStyle(.secondary)
              }.card()
            }.buttonStyle(.plain)
          }
          Text("Works offline. Export a copy to keep your memories beyond this phone.").font(
            .footnote
          ).foregroundStyle(.secondary).padding(.vertical)
        }.padding(22)
      }.canvas().safeAreaInset(edge: .bottom) {
        Button {
          starting = true
        } label: {
          Label("Start a trip", systemImage: "plus")
        }.buttonStyle(Pill(primary: true)).disabled(!journal.ready).padding(20).background(
          Style.paper)
      }.sheet(isPresented: $starting) { StartTrip() }
    }
  }
}
struct StartTrip: View {
  @EnvironmentObject var journal: Journal
  @EnvironmentObject var position: Position
  @Environment(\.dismiss) var dismiss
  @State var title = ""
  @State var water = ""
  @State var companions = ""
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          Intro(title: "Starting out", subtitle: Date().formatted(date: .complete, time: .omitted))
          Text("Where you are").font(Style.heading(22))
          TextField("River or lake (optional)", text: $water).textFieldStyle(.roundedBorder)
          Text(position.status).font(.footnote).foregroundStyle(.secondary)
          Button("Use my location") { position.request() }
          TextField("Trip name (optional)", text: $title).textFieldStyle(.roundedBorder)
          TextField("Who's along? (optional)", text: $companions).textFieldStyle(.roundedBorder)
          Text(
            "Start with as little as you like. Time is automatic. Location is optional, and no river name is guessed."
          ).card()
          Button("We're fishing") {
            let trip = Trip(
              title: title.trimmingCharacters(in: .whitespacesAndNewlines),
              waterbody: water.trimmingCharacters(in: .whitespacesAndNewlines),
              companions: companions)
            if journal.commit({ $0.trips.append(trip) }) { dismiss() }
          }.buttonStyle(Pill(primary: true))
        }.padding(22)
      }.canvas().toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
      }
    }
  }
}
struct TripScreen: View {
  let id: UUID
  @EnvironmentObject var journal: Journal
  @EnvironmentObject var position: Position
  @State private var recording = false
  @State private var typing = false
  @State private var photos = false
  @State private var finishing = false
  @State private var exporting = false
  @State private var editing = false
  var trip: Trip? { journal.trip(id) }
  var body: some View {
    Group {
      if let trip {
        ScrollView {
          VStack(alignment: .leading, spacing: 18) {
            Intro(
              title: trip.name,
              subtitle: trip.endedAt == nil
                ? "Trip running · works offline" : "Trip ended · keep adding any time")
            HStack(alignment: .top) {
              VStack(alignment: .leading, spacing: 6) {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                  Text(duration((trip.endedAt ?? context.date).timeIntervalSince(trip.startedAt)))
                    .font(Style.heading(26))
                }
                Text("Time since you started — not time spent fishing.").font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              Button(trip.endedAt == nil ? "End trip" : "Reopen") {
                if trip.endedAt == nil {
                  finishing = true
                } else {
                  journal.update(id) { $0.endedAt = nil }
                }
              }.font(.subheadline.weight(.semibold))
            }.card()
            if trip.outcome != "unspecified" {
              Text(trip.outcome == "zero_catches" ? "No fish — said so" : "Caught something").font(
                .subheadline
              ).foregroundStyle(Style.sage)
            }
            if trip.visible.isEmpty {
              VStack(alignment: .leading, spacing: 10) {
                Text("Nothing saved yet").font(Style.heading(25))
                Text(
                  "Record a thought, take a photo, or type a few words. Sort out what it was later — or never."
                ).foregroundStyle(.secondary)
              }.padding(.vertical, 32)
            }
            ForEach(trip.visible) { moment in
              NavigationLink {
                MomentScreen(tripID: id, eventID: moment.id)
              } label: {
                MomentRow(moment: moment)
              }.buttonStyle(.plain)
            }
            Button {
              exporting = true
            } label: {
              Label(
                trip.lastExportedRevision == nil ? "Export this trip" : "Export a fresh copy",
                systemImage: "square.and.arrow.up")
            }.buttonStyle(Pill())
            if let revision = trip.lastExportedRevision, revision != trip.revision {
              Text("There are changes since your last export.").font(.caption)
            }
          }.padding(22)
        }.safeAreaInset(edge: .bottom) {
          CaptureBar(
            record: { recording = true }, photo: { photos = true }, type: { typing = true }
          ).padding(16).background(Style.paper)
        }
        .sheet(isPresented: $recording) { RecordScreen(tripID: id, existing: nil) }.sheet(
          isPresented: $typing
        ) { NoteSheet(tripID: id, existing: nil) }.sheet(isPresented: $photos) {
          PhotoSheet(tripID: id, existing: nil)
        }.sheet(isPresented: $finishing) { FinishSheet(tripID: id) }.sheet(isPresented: $exporting)
        { ExportSheet(tripID: id) }.sheet(isPresented: $editing) { TripEdit(tripID: id) }
      } else {
        Text("Trip unavailable")
      }
    }.canvas().navigationBarTitleDisplayMode(.inline).toolbar {
      Button {
        editing = true
      } label: {
        Image(systemName: "slider.horizontal.3")
      }.accessibilityLabel("Edit trip details")
    }.onAppear { position.request() }
  }
}
func duration(_ seconds: Double) -> String {
  let s = max(0, Int(seconds))
  return s >= 3600 ? "\(s/3600)h \((s%3600)/60)m" : "\(s/60)m \(s%60)s"
}
struct CaptureBar: View {
  var record: () -> Void
  var photo: () -> Void
  var type: () -> Void
  var body: some View {
    HStack(spacing: 10) {
      Button(action: record) {
        VStack(spacing: 6) {
          Image(systemName: "mic.fill")
          Text("Record")
        }
      }.buttonStyle(Pill(primary: true))
      Button(action: photo) {
        VStack(spacing: 6) {
          Image(systemName: "camera")
          Text("Photo")
        }
      }.buttonStyle(Pill())
      Button(action: type) {
        VStack(spacing: 6) {
          Image(systemName: "text.cursor")
          Text("Type")
        }
      }.buttonStyle(Pill())
    }
  }
}
struct MomentRow: View {
  var moment: Moment
  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: moment.kind.symbol).font(.title2).foregroundStyle(Style.sage)
      VStack(alignment: .leading, spacing: 9) {
        Text(
          moment.text.isEmpty
            ? (moment.attachments.isEmpty ? "A moment · no media yet" : "A moment on the water")
            : moment.text
        ).lineLimit(3)
        HStack {
          if moment.attachments.contains(where: { $0.mimeType.hasPrefix("audio") }) {
            Image(systemName: "waveform")
          }
          if moment.attachments.contains(where: { $0.mimeType.hasPrefix("image") }) {
            Image(systemName: "photo")
          }
          Text(moment.occurredAt?.formatted(date: .omitted, time: .shortened) ?? "Time unknown")
          if moment.kind != .unclassified { Text("· \(moment.kind.label)") }
        }.font(.caption).foregroundStyle(.secondary)
      }
      Spacer(minLength: 0)
      Image(systemName: "chevron.right").font(.caption)
    }.card()
  }
}
struct NoteSheet: View {
  let tripID: UUID
  let existing: UUID?
  @EnvironmentObject var journal: Journal
  @EnvironmentObject var position: Position
  @Environment(\.dismiss) var dismiss
  @State var text = ""
  @State var originalText = ""
  @State var discard = false
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          Intro(title: "Type a note", subtitle: "Your own words. No processing.")
          TextEditor(text: $text).frame(minHeight: 240).scrollContentBackground(.hidden).padding(12)
            .background(Style.surface, in: RoundedRectangle(cornerRadius: 20)).accessibilityLabel(
              "Note text")
          Text("A sentence is enough. You can add photos or audio to this same moment later.").font(
            .subheadline
          ).foregroundStyle(.secondary)
          Button("Save on this phone") {
            if let existing {
              if journal.edit(tripID, existing, {
                $0.textHistory.append(TextRevision(text: text, savedAt: Date()))
              }) { dismiss() }
            } else if journal.add(trip: tripID, text: text, fix: position.current()) != nil {
              dismiss()
            }
          }.buttonStyle(Pill(primary: true)).disabled(
            existing == nil ? text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty : text == originalText)
        }.padding(22)
      }.canvas().interactiveDismissDisabled(text != originalText).confirmationDialog(
        "Discard your unsaved words?", isPresented: $discard, titleVisibility: .visible
      ) { Button("Discard changes", role: .destructive) { dismiss() } }.toolbar {
        Button("Cancel") { if text != originalText { discard = true } else { dismiss() } }
      }.onAppear {
        if let existing {
          text = journal.trip(tripID)?.moments.first(where: { $0.id == existing })?.text ?? ""
        }
        originalText = text
      }
    }
  }
}
struct RecordScreen: View {
  let tripID: UUID
  let existing: UUID?
  var initialKind: MomentKind = .unclassified
  @EnvironmentObject var journal: Journal
  @EnvironmentObject var position: Position
  @Environment(\.dismiss) var dismiss
  @StateObject private var voice = VoiceRecorder()
  var body: some View {
    NavigationStack {
      VStack(spacing: 25) {
        Intro(
          title: voice.recording ? "Recording" : "Your voice",
          subtitle: "Keep Creel open while you talk.")
        Spacer()
        Image(systemName: voice.recording ? "waveform" : "mic").font(.system(size: 72))
          .foregroundStyle(Style.orange).symbolEffect(.pulse, isActive: voice.recording)
        Text(duration(voice.elapsed)).font(Style.heading(48)).monospacedDigit()
        Text(voice.message).multilineTextAlignment(.center).accessibilityIdentifier(
          "recordingStatus")
        Text(
          "Audio is saved in 30-second parts within one moment. A long story is welcome. Leaving the app stops recording."
        ).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        Spacer()
        if voice.recording {
          Button("Stop and save") { voice.stop() }.buttonStyle(Pill(primary: true))
        } else {
          Button(voice.eventID == nil ? "Record" : "Record another part") {
            Task {
              await voice.start(
                journal: journal, trip: tripID, existing: voice.eventID ?? existing,
                fix: position.current(), initialKind: initialKind)
            }
          }.buttonStyle(Pill(primary: true))
          Button("Back to trip") { dismiss() }.buttonStyle(Pill())
        }
      }.padding(22).canvas().interactiveDismissDisabled(voice.recording).toolbar {
        if !voice.recording { Button("Done") { dismiss() } }
      }.task {
        await voice.start(
          journal: journal, trip: tripID, existing: existing, fix: position.current(),
          initialKind: initialKind)
      }.onDisappear { voice.stop() }
    }
  }
}
struct MomentScreen: View {
  let tripID: UUID
  let eventID: UUID
  @EnvironmentObject var journal: Journal
  @Environment(\.dismiss) var dismiss
  @State var note = false
  @State var photo = false
  @State var voice = false
  @State var time = false
  @State var deleting = false
  @StateObject var player = Playback()
  var event: Moment? { journal.trip(tripID)?.moments.first { $0.id == eventID } }
  var body: some View {
    ScrollView {
      if let event {
        VStack(alignment: .leading, spacing: 20) {
          Intro(title: "A moment", subtitle: "Add more any time.")
          Label(
            event.attachments.isEmpty && event.text.isEmpty
              ? "Moment saved · no media attached" : "Saved on this device",
            systemImage: "checkmark.circle.fill"
          ).font(.subheadline).foregroundStyle(Style.sage)
          ForEach(event.attachments) { attachment in
            if attachment.mimeType.hasPrefix("image"),
              let image = UIImage(
                contentsOfFile: journal.repo.root.appendingPathComponent(attachment.path).path)
            {
              VStack(alignment: .leading) {
                Image(uiImage: image).resizable().scaledToFit().clipShape(
                  RoundedRectangle(cornerRadius: 20))
                Text(
                  "Original photo · \(ByteCountFormatter.string(fromByteCount: Int64(attachment.byteLength), countStyle: .file))"
                ).font(.caption).foregroundStyle(.secondary)
              }
            } else if attachment.mimeType.hasPrefix("image") {
              Label(
                "Photo preview unavailable. The original file is retained.",
                systemImage: "photo.badge.exclamationmark"
              ).card()
            } else {
              Button {
                player.toggle(attachment, root: journal.repo.root)
              } label: {
                HStack {
                  Image(
                    systemName: player.playing == attachment.id
                      ? "stop.circle.fill" : "play.circle.fill"
                  ).font(.largeTitle)
                  VStack(alignment: .leading) {
                    Text("Original audio")
                    Text(duration(attachment.duration ?? 0)).font(.caption)
                  }
                  Spacer()
                }.card()
              }.buttonStyle(.plain)
            }
          }
          if !event.text.isEmpty { Text(event.text).textSelection(.enabled).card() }
          Button(event.text.isEmpty ? "Add a few words" : "Edit your words") { note = true }
          if event.textHistory.count > 1 {
            DisclosureGroup("Earlier versions (\(event.textHistory.count - 1))") {
              ForEach(Array(event.textHistory.dropLast().enumerated()), id: \.offset) { _, r in
                VStack(alignment: .leading) {
                  Text(r.savedAt.formatted()).font(.caption)
                  Text(r.text)
                }.padding(.vertical, 6)
              }
            }
          }
          Text("What kind of moment?").font(Style.heading(23))
          ScrollView(.horizontal, showsIndicators: false) {
            HStack {
              ForEach(MomentKind.allCases, id: \.self) { kind in
                Button(kind.label) { journal.edit(tripID, eventID) { $0.kind = kind } }.padding(12)
                  .background(
                    event.kind == kind ? Style.sage.opacity(0.35) : Style.surface, in: Capsule())
              }
            }
          }
          VStack(alignment: .leading, spacing: 12) {
            Text("Time & place").font(Style.heading(22))
            Text("Recorded \(event.capturedAt.formatted())")
            Text(
              event.occurredAt.map { "Happened \($0.formatted())" } ?? "When it happened is unknown"
            )
            if let until = event.occurredUntil { Text("Until \(until.formatted())") }
            Text(
              event.occurrenceBasis == "capture_time"
                ? "Time defaults to capture time."
                : "Time supplied later; capture location is not assigned to this event."
            ).font(.caption).foregroundStyle(.secondary)
            if let fix = event.captureLocation {
              Text(
                String(
                  format: "Capture GPS: %.5f, %.5f · ±%.0f m", fix.latitude, fix.longitude,
                  fix.accuracyMeters)
              ).font(.caption)
              Text("Fix: \(fix.measuredAt.formatted())").font(.caption)
            } else {
              Text("Capture location unknown").font(.caption)
            }
            Button("It happened earlier / change time") { time = true }
          }.card()
          Button("Add a photo to this") { photo = true }.buttonStyle(Pill())
          Button("Add more audio") { voice = true }.buttonStyle(Pill())
          Button("Remove this moment", role: .destructive) { deleting = true }.padding(.top)
        }.padding(22)
      }
    }.canvas().sheet(isPresented: $note) { NoteSheet(tripID: tripID, existing: eventID) }.sheet(
      isPresented: $photo
    ) { PhotoSheet(tripID: tripID, existing: eventID) }.sheet(isPresented: $voice) {
      RecordScreen(tripID: tripID, existing: eventID)
    }.sheet(isPresented: $time) { TimeSheet(tripID: tripID, eventID: eventID) }.confirmationDialog(
      "Remove this moment from the timeline? Its original files and deletion marker remain in exports.",
      isPresented: $deleting, titleVisibility: .visible
    ) {
      Button("Remove moment", role: .destructive) {
        if journal.edit(tripID, eventID, { $0.deleted = true }) { dismiss() }
      }
    }.alert(
      "Playback unavailable",
      isPresented: Binding(get: { player.error != nil }, set: { if !$0 { player.error = nil } })
    ) {
      Button("OK") { player.error = nil }
    } message: {
      Text(player.error ?? "")
    }.onDisappear { player.stop() }
  }
}
struct TimeSheet: View {
  var tripID: UUID
  var eventID: UUID
  @EnvironmentObject var journal: Journal
  @Environment(\.dismiss) var dismiss
  @State var mode = "exact"
  @State var start = Date()
  @State var end = Date()
  var body: some View {
    NavigationStack {
      Form {
        Section {
          Text("When was this?").font(Style.heading())
          Picker("Time", selection: $mode) {
            Text("Earlier / exact time").tag("exact")
            Text("A time range").tag("range")
            Text("I don't know").tag("unknown")
            Text("At capture time").tag("capture")
          }
          if mode == "exact" || mode == "range" { DatePicker("Happened", selection: $start) }
          if mode == "range" { DatePicker("Until", selection: $end, in: start...) }
        }
        Section {
          Text(
            "The original capture time and GPS stay unchanged. An earlier event's location will remain unknown."
          )
          Button("Save correction") {
            if journal.edit(
              tripID, eventID,
              { e in
                e.occurredAt = mode == "unknown" ? nil : (mode == "capture" ? e.capturedAt : start)
                e.occurredUntil = mode == "range" ? max(start, end) : nil
                e.occurrenceBasis =
                  mode == "capture"
                  ? "capture_time"
                  : (mode == "range" ? "user_range" : (mode == "unknown" ? "unknown" : "user_time"))
                e.eventLocation = mode == "capture" ? e.captureLocation : nil
              })
            {
              dismiss()
            }
          }
        }
      }.scrollContentBackground(.hidden).canvas().toolbar { Button("Cancel") { dismiss() } }
        .onAppear {
          if let e = journal.trip(tripID)?.moments.first(where: { $0.id == eventID }) {
            start = e.occurredAt ?? e.capturedAt
            end = e.occurredUntil ?? start
            mode =
              e.occurrenceBasis == "capture_time"
              ? "capture"
              : (e.occurredUntil != nil ? "range" : (e.occurredAt == nil ? "unknown" : "exact"))
          }
        }
    }
  }
}
struct FinishSheet: View {
  var tripID: UUID
  @EnvironmentObject var journal: Journal
  @Environment(\.dismiss) var dismiss
  @State var outcome = "unspecified"
  @State var end = Date()
  @State var debrief = false
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          Intro(title: "Wrapping up", subtitle: "You can come back and add more later.")
          Button {
            debrief = true
          } label: {
            Label("Record a debrief", systemImage: "mic")
          }.buttonStyle(Pill())
          Text("How'd it go?").font(Style.heading(24))
          ForEach(
            [
              ("caught_something", "Caught something"), ("zero_catches", "Blanked — no fish"),
              ("unspecified", "Rather not say"),
            ], id: \.0
          ) { value, label in
            Button {
              outcome = value
            } label: {
              HStack {
                Text(label)
                Spacer()
                Image(systemName: outcome == value ? "checkmark.circle.fill" : "circle")
              }.card()
            }.buttonStyle(.plain)
          }
          DatePicker(
            "Ended", selection: $end, in: (journal.trip(tripID)?.startedAt ?? Date.distantPast)...)
          Button("End trip") {
            if journal.update(
              tripID,
              {
                $0.endedAt = end
                $0.outcome = outcome
              })
            {
              dismiss()
            }
          }.buttonStyle(Pill(primary: true))
        }.padding(22)
      }.canvas().toolbar { Button("Cancel") { dismiss() } }.sheet(isPresented: $debrief) {
        RecordScreen(tripID: tripID, existing: nil, initialKind: .journal)
      }.onAppear { outcome = journal.trip(tripID)?.outcome ?? "unspecified" }
    }
  }
}
struct TripEdit: View {
  var tripID: UUID
  @EnvironmentObject var journal: Journal
  @Environment(\.dismiss) var dismiss
  @State var title = ""
  @State var water = ""
  @State var companions = ""
  @State var start = Date()
  @State var ended = false
  @State var end = Date()
  @State var outcome = "unspecified"
  var body: some View {
    NavigationStack {
      Form {
        TextField("Trip name", text: $title)
        TextField("River or lake", text: $water)
        TextField("Companions", text: $companions)
        DatePicker("Started", selection: $start)
        if ended { DatePicker("Ended", selection: $end, in: start...) }
        Picker("Result", selection: $outcome) {
          Text("Not specified").tag("unspecified")
          Text("Caught something").tag("caught_something")
          Text("No fish — said so").tag("zero_catches")
        }
        Button("Save details") {
          guard !ended || start <= end else {
            journal.error = "Start must be before the trip's end."
            return
          }
          if journal.update(
            tripID,
            {
              $0.title = title
              $0.waterbody = water
              $0.companions = companions
              $0.startedAt = start
              $0.endedAt = ended ? end : nil
              $0.outcome = outcome
            })
          {
            dismiss()
          }
        }
      }.scrollContentBackground(.hidden).canvas().navigationTitle("Trip details").toolbar {
        Button("Cancel") { dismiss() }
      }.onAppear {
        if let t = journal.trip(tripID) {
          title = t.title
          water = t.waterbody
          companions = t.companions
          start = t.startedAt
          ended = t.endedAt != nil
          end = t.endedAt ?? Date()
          outcome = t.outcome
        }
      }
    }
  }
}
struct ExportSheet: View {
  var tripID: UUID
  @EnvironmentObject var journal: Journal
  @Environment(\.dismiss) var dismiss
  @State var url: URL?
  @State var sharing = false
  @State var working = false
  @State var problem: String?
  @State var handed = false
  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 24) {
        Intro(title: "Hand it over", subtitle: "One file, originals inside.")
        if let trip = journal.trip(tripID) {
          Text(trip.name).font(Style.heading(25))
          Text(
            "\(trip.visible.count) moments · \(trip.moments.flatMap(\.attachments).count) original files"
          )
          Text(
            "The package includes your notes, photos, audio, timestamps and available locations. Save it to Files or transfer it to your computer. Your trip stays here."
          ).card()
        }
        if working { ProgressView("Checking originals & packing…") }
        if let problem { Text(problem).foregroundStyle(.red) }
        if let url {
          Text(
            handed
              ? "The share flow completed. Creel cannot confirm delivery to your computer."
              : "Package created on this phone. Choose where to save it."
          ).foregroundStyle(Style.sage)
          Text(url.lastPathComponent).font(.caption).textSelection(.enabled)
          Button("Save or share the file") { sharing = true }.buttonStyle(Pill(primary: true))
        } else {
          Button("Create trip package") { makeExport() }.buttonStyle(Pill(primary: true)).disabled(
            working)
        }
        Text(
          "Anyone with this file can read it, including its locations. Nothing is sent automatically."
        ).font(.footnote).foregroundStyle(.secondary)
        Spacer()
        Button("Back to trip") { dismiss() }.buttonStyle(Pill())
      }.padding(22).canvas().sheet(isPresented: $sharing) {
        if let url { ShareSheet(url: url) { completed in handed = completed } }
      }.toolbar { Button("Done") { dismiss() } }
    }
  }
  func makeExport() {
    guard let trip = journal.trip(tripID) else { return }
    working = true
    problem = nil
    let repo = journal.repo
    Task {
      do {
        let exported = try await Task.detached { try repo.export(trip) }.value
        url = exported
        _ = journal.commit { lib in
          if let i = lib.trips.firstIndex(where: { $0.id == tripID }),
            lib.trips[i].revision == trip.revision
          {
            lib.trips[i].lastExportedRevision = trip.revision
          }
        }
      } catch { problem = "Export could not finish: \(error.localizedDescription)" }
      working = false
    }
  }
}
struct ShareSheet: UIViewControllerRepresentable {
  let url: URL
  var finished: (Bool) -> Void
  func makeUIViewController(context: Context) -> UIActivityViewController {
    let c = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    c.completionWithItemsHandler = { _, completed, _, _ in finished(completed) }
    return c
  }
  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
