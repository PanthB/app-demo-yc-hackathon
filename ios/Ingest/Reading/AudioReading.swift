import Foundation
import Speech

enum AudioReading {
    struct Heard: Sendable {
        var text: String?
        var note: String?
    }

    private final class Listening: @unchecked Sendable {
        let lock = NSLock()
        var answered = false
        var task: SFSpeechRecognitionTask?
        let recognizer: SFSpeechRecognizer

        init(recognizer: SFSpeechRecognizer) {
            self.recognizer = recognizer
        }

        func claim() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            if answered { return false }
            answered = true
            return true
        }
    }

    static func transcribe(_ url: URL) async -> Heard {
        let status: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard status == .authorized else {
            return Heard(note: "speech recognition isn't allowed, so this voice note keeps its audio and has no words yet")
        }
        guard let recognizer = SFSpeechRecognizer() ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US")), recognizer.isAvailable else {
            return Heard(note: "no speech recognizer is available for this language right now")
        }
        guard recognizer.supportsOnDeviceRecognition else {
            return Heard(note: "on-device speech recognition isn't available here, and the app never sends audio away")
        }
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        request.addsPunctuation = true

        let listening = Listening(recognizer: recognizer)
        return await withCheckedContinuation { (continuation: CheckedContinuation<Heard, Never>) in
            listening.task = recognizer.recognitionTask(with: request) { result, error in
                let isFinal = result?.isFinal == true
                guard isFinal || error != nil, listening.claim() else { return }
                let text = result?.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if isFinal, !text.isEmpty {
                    continuation.resume(returning: Heard(text: text))
                } else {
                    continuation.resume(returning: Heard(note: "speech recognition found no words: \(error.map { String(describing: $0) } ?? "the recording was silent")"))
                }
            }
        }
    }
}
