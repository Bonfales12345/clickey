import AVFoundation

class AudioManager {
    static let shared = AudioManager()
    
    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var buffer: AVAudioPCMBuffer?
    private var currentPlayerIndex = 0
    private let poolSize = 10
    
    private let volumeKey = "com.clickey.volume"
    private let pausedKey = "com.clickey.paused"

    var volume: Float {
        get {
            return UserDefaults.standard.object(forKey: volumeKey) != nil ? UserDefaults.standard.float(forKey: volumeKey) : 0.8
        }
        set {
            UserDefaults.standard.set(newValue, forKey: volumeKey)
            engine.mainMixerNode.outputVolume = newValue
        }
    }
    
    var isPaused: Bool {
        get { UserDefaults.standard.bool(forKey: pausedKey) }
        set { UserDefaults.standard.set(newValue, forKey: pausedKey) }
    }

    private init() {
        registerDefaults()
        prepareAudio()
    }
    
    private func registerDefaults() {
        UserDefaults.standard.register(defaults: [volumeKey: 0.8, pausedKey: false])
    }

    private func prepareAudio() {
        guard let url = Bundle.main.url(forResource: "creamy", withExtension: "wav") else {
            print("Error: creamy.wav not found.") // this is the keyboard switch sound btw
            return
        }

        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let frameCount = AVAudioFrameCount(file.length)

            guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                return
            }
            
            try file.read(into: pcmBuffer)
            self.buffer = pcmBuffer

            let mainMixer = engine.mainMixerNode
            mainMixer.outputVolume = self.volume

            for _ in 0..<poolSize {
                let player = AVAudioPlayerNode()
                engine.attach(player)
                try engine.connect(player, to: mainMixer, format: format)
                players.append(player)
            }

            engine.prepare()
            try engine.start()
        } catch {
            print("engine failed: \(error.localizedDescription)")
        }
    }

    func play() {
        // turn off sound
        guard !isPaused, let buffer = buffer else { return }

        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }
            
            let player = self.players[self.currentPlayerIndex]
            
            if player.isPlaying {
                player.stop()
            }

            player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
            try? player.play()

            self.currentPlayerIndex = (self.currentPlayerIndex + 1) % self.poolSize
        }
    }
    
    func stopAudio() {
        engine.stop()
        for player in players {
            player.stop()
        }
    }
}
