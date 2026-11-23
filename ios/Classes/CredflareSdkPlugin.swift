import CoreVideo
import Flutter
import UIKit
import Vision

public final class CredflareSdkPlugin: NSObject, FlutterPlugin {
  private let queue = DispatchQueue(label: "net.credflare.sdk.faces", qos: .userInitiated)

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "credflare_sdk/faces", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(CredflareSdkPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "vision#process":
      guard let args = call.arguments as? [String: Any], let bytes = args["bytes"] as? FlutterStandardTypedData,
            let width = args["width"] as? Int, let height = args["height"] as? Int,
            let bytesPerRow = args["bytesPerRow"] as? Int else {
        result(FlutterError(code: "invalid_frame", message: "A frame needs bytes, width, height and bytesPerRow.", details: nil))
        return
      }
      queue.async {
        let reading = VisionFaceReader.read(bgra: bytes.data, width: width, height: height, bytesPerRow: bytesPerRow)
        DispatchQueue.main.async { result(reading) }
      }
    case "vision#close":
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

enum VisionFaceReader {
  static func read(bgra: Data, width: Int, height: Int, bytesPerRow: Int) -> [String: Any] {
    guard width > 0, height > 0, bytesPerRow >= width * 4, bgra.count >= bytesPerRow * height,
          let pixels = pixelBuffer(bgra, width: width, height: height, bytesPerRow: bytesPerRow) else {
      return ["faces": 0]
    }
    let handler = VNImageRequestHandler(cvPixelBuffer: pixels, orientation: .up, options: [:])
    return read(handler: handler, size: CGSize(width: width, height: height))
  }

  static func read(handler: VNImageRequestHandler, size: CGSize) -> [String: Any] {
    let rectangles = VNDetectFaceRectanglesRequest()
    rectangles.revision = VNDetectFaceRectanglesRequestRevision3
    do { try handler.perform([rectangles]) } catch { return ["faces": 0] }
    let faces = rectangles.results ?? []
    guard faces.count == 1, let face = faces.first else { return ["faces": faces.count] }
    let landmarks = VNDetectFaceLandmarksRequest()
    landmarks.revision = VNDetectFaceLandmarksRequestRevision3
    landmarks.inputFaceObservations = [face]
    try? handler.perform([landmarks])
    let marks = landmarks.results?.first?.landmarks
    let box = face.boundingBox
    var reading: [String: Any] = [
      "faces": 1,
      "x": Double(box.minX), "y": Double(box.minY), "width": Double(box.width), "height": Double(box.height),
    ]
    if let yaw = face.yaw { reading["yaw"] = yaw.doubleValue }
    if let pitch = face.pitch { reading["pitch"] = pitch.doubleValue }
    if let left = marks?.leftEye?.pointsInImage(imageSize: size), let right = marks?.rightEye?.pointsInImage(imageSize: size),
       let a = eyeAspectRatio(left), let b = eyeAspectRatio(right) {
      reading["eye_ratio"] = (a + b) / 2
    }
    if let lips = marks?.outerLips?.pointsInImage(imageSize: size), let lp = marks?.leftPupil?.pointsInImage(imageSize: size).first,
       let rp = marks?.rightPupil?.pointsInImage(imageSize: size).first,
       let ratio = mouthWidthRatio(lips: lips, leftPupil: lp, rightPupil: rp) {
      reading["mouth_ratio"] = ratio
    }
    return reading
  }

  static func eyeAspectRatio(_ points: [CGPoint]) -> Double? {
    guard points.count >= 4, let minX = points.map(\.x).min(), let maxX = points.map(\.x).max(),
          let minY = points.map(\.y).min(), let maxY = points.map(\.y).max(), maxX > minX else { return nil }
    return Double((maxY - minY) / (maxX - minX))
  }

  static func mouthWidthRatio(lips: [CGPoint], leftPupil: CGPoint, rightPupil: CGPoint) -> Double? {
    guard let minX = lips.map(\.x).min(), let maxX = lips.map(\.x).max() else { return nil }
    let pupils = hypot(leftPupil.x - rightPupil.x, leftPupil.y - rightPupil.y)
    guard pupils > 0 else { return nil }
    return Double((maxX - minX) / pupils)
  }

  private static func pixelBuffer(_ data: Data, width: Int, height: Int, bytesPerRow: Int) -> CVPixelBuffer? {
    var buffer: CVPixelBuffer?
    let attributes = [kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()] as CFDictionary
    guard CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attributes, &buffer) == kCVReturnSuccess,
          let buffer else { return nil }
    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
    let target = CVPixelBufferGetBytesPerRow(buffer)
    let row = min(target, bytesPerRow)
    data.withUnsafeBytes { (source: UnsafeRawBufferPointer) in
      guard let start = source.baseAddress else { return }
      for y in 0..<height {
        memcpy(base.advanced(by: y * target), start.advanced(by: y * bytesPerRow), row)
      }
    }
    return buffer
  }
}
