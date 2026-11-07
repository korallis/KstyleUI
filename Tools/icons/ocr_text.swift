// ocr_text.swift: prints the text macOS Vision finds in each image path given, one JSON line per image.
// Tools/icons/check_icons.py compiles it with swiftc and reads its output. macOS only.
import Foundation
import ImageIO
import Vision

for path in CommandLine.arguments.dropFirst() {
    var line: [String: Any] = ["path": path]
    var texts: [[String: Any]] = []
    let url = URL(fileURLWithPath: path)
    if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
       let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        do {
            try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
            for observation in request.results ?? [] {
                if let best = observation.topCandidates(1).first {
                    texts.append(["text": best.string, "confidence": Double(best.confidence)])
                }
            }
        } catch {
            line["error"] = "\(error)"
        }
    } else {
        line["error"] = "cannot read the image"
    }
    line["texts"] = texts
    let data = try JSONSerialization.data(withJSONObject: line, options: [.sortedKeys])
    print(String(decoding: data, as: UTF8.self))
}
