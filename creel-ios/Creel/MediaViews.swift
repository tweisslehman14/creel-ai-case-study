import AVFoundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct PhotoSheet: View {
  let tripID: UUID
  let existing: UUID?
  @EnvironmentObject var journal: Journal
  @EnvironmentObject var position: Position
  @Environment(\.dismiss) var dismiss
  @State private var picker = false
  @State private var camera = false
  @State private var files = false
  @State private var busy = false
  @State private var problem: String?
  @State private var discard = false
  @State private var pendingData: Data?
  @State private var pendingType: UTType?
  @State private var pendingOrigin = ""
  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 24) {
        Intro(title: "A photo is enough", subtitle: "Add words now, later, or never.")
        Image(systemName: "camera.aperture").font(.system(size: 85)).foregroundStyle(Style.sage)
          .frame(maxWidth: .infinity).padding(.vertical, 30)
        Text(
          "Choose a photo already on this phone, or take one. The image file is kept with your trip."
        ).card()
        Button("Take a photo") {
          Task {
            let allowed = await AVCaptureDevice.requestAccess(for: .video)
            if allowed {
              camera = true
            } else {
              problem = "Camera access is off. Choose a photo or enable Camera in Settings."
            }
          }
        }.buttonStyle(Pill(primary: true)).disabled(
          !UIImagePickerController.isSourceTypeAvailable(.camera) || busy)
        if !UIImagePickerController.isSourceTypeAvailable(.camera) {
          Text("This simulator has no camera. Choose a photo or image file to test capture.").font(
            .caption
          ).foregroundStyle(.secondary)
        }
        Button("Choose from Photos") { picker = true }.buttonStyle(Pill()).disabled(busy)
        Button("Choose an image file") { files = true }.buttonStyle(Pill()).disabled(busy)
        if busy { ProgressView("Saving original on this phone…") }
        if let problem {
          Text(problem).foregroundStyle(.red)
          if pendingData != nil {
            Button("Retry save") { savePending() }.buttonStyle(Pill(primary: true))
          }
        }
        Spacer()
      }.padding(22).canvas().interactiveDismissDisabled(busy || pendingData != nil)
        .confirmationDialog(
          "Leave without saving this photo?", isPresented: $discard, titleVisibility: .visible
        ) { Button("Discard unsaved photo", role: .destructive) { dismiss() } }.toolbar {
          Button("Cancel") { if pendingData != nil { discard = true } else { dismiss() } }.disabled(
            busy)
        }
        .sheet(isPresented: $picker) {
          OriginalPhotoPicker { result in
            picker = false
            accept(result, origin: "photo_library")
          }
        }
        .fullScreenCover(isPresented: $camera) {
          CameraCapture { result in
            camera = false
            if let result { accept(result, origin: "camera") }
          }
        }
        .fileImporter(isPresented: $files, allowedContentTypes: [.image]) { result in
          do {
            let url = try result.get()
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let type = UTType(filenameExtension: url.pathExtension) ?? .image
            accept(.success((data, type)), origin: "image_file")
          } catch { problem = error.localizedDescription }
        }
    }
  }
  func accept(_ result: Result<(Data, UTType), Error>, origin: String) {
    switch result {
    case .success(let (bytes, type)):
      pendingData = bytes
      pendingType = type
      pendingOrigin = origin
      savePending()
    case .failure(let error): problem = "Photo was not saved: \(error.localizedDescription)"
    }
  }
  func savePending() {
    guard let data = pendingData, let type = pendingType else { return }
    busy = true
    problem = nil
    do {
      guard UIImage(data: data) != nil else {
        throw CreelError.message(
          "This image format cannot be previewed on this device. The source file was not changed.")
      }
      let attachment = try journal.repo.media(
        data, ext: type.preferredFilenameExtension ?? "image",
        mime: type.preferredMIMEType ?? "application/octet-stream", origin: pendingOrigin)
      if journal.add(
        trip: tripID, attachment: attachment, fix: position.current(), existing: existing,
        immediate: pendingOrigin == "camera") != nil
      {
        pendingData = nil
        dismiss()
      } else {
        problem = "The photo has not been added to your trip. Retry when storage is available."
      }
    } catch { problem = "Photo was not saved: \(error.localizedDescription)" }
    busy = false
  }
}

// Current representation avoids automatic compatibility transcoding by Photos.
struct OriginalPhotoPicker: UIViewControllerRepresentable {
  var completion: (Result<(Data, UTType), Error>) -> Void
  func makeCoordinator() -> Coordinator { Coordinator(completion) }
  func makeUIViewController(context: Context) -> PHPickerViewController {
    var config = PHPickerConfiguration()
    config.filter = .images
    config.selectionLimit = 1
    config.preferredAssetRepresentationMode = .current
    let picker = PHPickerViewController(configuration: config)
    picker.delegate = context.coordinator
    return picker
  }
  func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
  final class Coordinator: NSObject, PHPickerViewControllerDelegate {
    let completion: (Result<(Data, UTType), Error>) -> Void
    init(_ completion: @escaping (Result<(Data, UTType), Error>) -> Void) {
      self.completion = completion
    }
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
      guard let item = results.first?.itemProvider else {
        picker.dismiss(animated: true)
        return
      }
      guard
        let type = item.registeredTypeIdentifiers.compactMap(UTType.init).first(where: {
          $0.conforms(to: .image)
        })
      else {
        completion(.failure(CreelError.message("No readable image was supplied.")))
        return
      }
      item.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, error in
        DispatchQueue.main.async {
          if let data {
            self.completion(.success((data, type)))
          } else {
            self.completion(
              .failure(
                error
                  ?? CreelError.message(
                    "The photo could not be loaded. If it is only in iCloud, download it before going offline."
                  )))
          }
        }
      }
    }
  }
}

struct CameraCapture: UIViewControllerRepresentable {
  var completion: (Result<(Data, UTType), Error>?) -> Void
  func makeCoordinator() -> Coordinator { Coordinator(completion) }
  func makeUIViewController(context: Context) -> CameraController {
    let c = CameraController()
    c.result = completion
    return c
  }
  func updateUIViewController(_ uiViewController: CameraController, context: Context) {}
  final class Coordinator {
    init(_ completion: @escaping (Result<(Data, UTType), Error>?) -> Void) {}
  }
}
// AVCapturePhoto supplies original encoded bytes directly; no UIImage JPEG recompression.
final class CameraController: UIViewController, AVCapturePhotoCaptureDelegate {
  var result: ((Result<(Data, UTType), Error>?) -> Void)?
  private let session = AVCaptureSession()
  private let output = AVCapturePhotoOutput()
  private var preview: AVCaptureVideoPreviewLayer?
  private let queue = DispatchQueue(label: "creel.camera")
  private var shutter = UIButton(type: .system)
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
    let cancel = UIButton(type: .system)
    cancel.setTitle("Cancel", for: .normal)
    cancel.setTitleColor(.white, for: .normal)
    cancel.addTarget(self, action: #selector(cancelCapture), for: .touchUpInside)
    cancel.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(cancel)
    shutter.setTitle("Take photo", for: .normal)
    shutter.backgroundColor = .white
    shutter.setTitleColor(.black, for: .normal)
    shutter.layer.cornerRadius = 28
    shutter.addTarget(self, action: #selector(takePhoto), for: .touchUpInside)
    shutter.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(shutter)
    NSLayoutConstraint.activate([
      cancel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
      cancel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
      shutter.bottomAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
      shutter.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      shutter.widthAnchor.constraint(equalToConstant: 180),
      shutter.heightAnchor.constraint(equalToConstant: 56),
    ])
    do {
      guard let device = AVCaptureDevice.default(for: .video) else {
        throw CreelError.message("No camera is available.")
      }
      let input = try AVCaptureDeviceInput(device: device)
      session.beginConfiguration()
      session.sessionPreset = .photo
      guard session.canAddInput(input), session.canAddOutput(output) else {
        throw CreelError.message("Camera could not be configured.")
      }
      session.addInput(input)
      session.addOutput(output)
      session.commitConfiguration()
      let layer = AVCaptureVideoPreviewLayer(session: session)
      layer.videoGravity = .resizeAspectFill
      view.layer.insertSublayer(layer, at: 0)
      preview = layer
      queue.async { self.session.startRunning() }
    } catch { result?(.failure(error)) }
  }
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    preview?.frame = view.bounds
  }
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    queue.async { self.session.stopRunning() }
  }
  @objc private func cancelCapture() { result?(nil) }
  @objc private func takePhoto() {
    shutter.isEnabled = false
    let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
    output.capturePhoto(with: settings, delegate: self)
  }
  func photoOutput(
    _ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?
  ) {
    DispatchQueue.main.async {
      if let bytes = photo.fileDataRepresentation() {
        self.result?(.success((bytes, .jpeg)))
      } else {
        self.result?(.failure(error ?? CreelError.message("The camera did not return a photo.")))
      }
    }
  }
}
