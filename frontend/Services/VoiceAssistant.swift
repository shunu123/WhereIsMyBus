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
    
    // TTS Synthesizer
    private let synthesizer = AVSpeechSynthesizer()
    
    // Silence detection
    private var silenceTimer: Timer?
    var onSilenceRecognized: (() -> Void)?

    func speak(text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        // Stop currently speaking
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        synthesizer.speak(utterance)
    }

    func start() async {
        guard !isListening else { return }
        
        // Stop speaking if starting
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        isListening = true
        transcript = ""
        audioLevel = 0.0

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
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
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
        
        var lastUpdate = Date().timeIntervalSince1970
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
            
            // Throttle MainActor updates to ~20fps to prevent massive SwiftUI lag
            let now = Date().timeIntervalSince1970
            if now - lastUpdate > 0.05 {
                lastUpdate = now
                Task { @MainActor in
                    self.audioLevel = level
                }
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
        restartSilenceTimer()

        task = recognizer?.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let r = result {
                self.transcript = r.bestTranscription.formattedString
                self.restartSilenceTimer()
            }
            if error != nil {
                self.stop()
            }
        }
    }

    private func restartSilenceTimer() {
        silenceTimer?.invalidate()
        // Wait 3.5 seconds of silence before assuming the user is done speaking
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isListening else { return }
                self.stop()
                self.onSilenceRecognized?()
            }
        }
    }

    func stop() {
        guard isListening else { return }
        isListening = false
        silenceTimer?.invalidate()

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        request?.endAudio()
        request = nil

        task?.cancel()
        task = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
