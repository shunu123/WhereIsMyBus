import Foundation
import Combine
import Speech
import AVFoundation

@MainActor
final class VoiceAssistant: ObservableObject {
    @Published var transcript: String = ""
    @Published var isListening: Bool = false
    @Published var audioLevel: Float = 0.0

    private let recognizer = SFSpeechRecognizer()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    func start() async {
        guard !isListening else { return }
        
        // Instant UI feedback
        isListening = true
        transcript = ""
        audioLevel = 0.0

        // ... auth check same as before ...
        let auth = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in 
                cont.resume(returning: status) 
            }
        }
        
        guard auth == .authorized else { 
            isListening = false
            return 
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch { 
            isListening = false
            return 
        }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        request = req

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            req.append(buffer)
            
            // Calculate audio level (RMS)
            guard let self, let channelData = buffer.floatChannelData?[0] else { return }
            let frames = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<frames {
                sum += channelData[i] * channelData[i]
            }
            let rms = sqrt(sum / Float(frames))
            let level = min(max(rms * 10, 0), 1) // Normalized 0 to 1
            Task { @MainActor in
                self.audioLevel = level
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch { 
            isListening = false
            return 
        }

        print("VoiceAssistant: Listening started...")

        task = recognizer?.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let r = result {
                self.transcript = r.bestTranscription.formattedString
            }
            if error != nil {
                self.stop()
            }
        }
    }

    func stop() {
        guard isListening else { return }
        isListening = false

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        request?.endAudio()
        request = nil

        task?.cancel()
        task = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
