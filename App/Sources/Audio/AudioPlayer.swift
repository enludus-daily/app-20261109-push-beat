import AVFoundation
import QuartzCore

/// 曲と触れた音を鳴らす。時刻は CACurrentMediaTime（host time）で、遊びの時計と合わせる。
/// 音が出せない（シミュレータ・失敗）ときも、遊びは時計だけで進む。
@MainActor
final class AudioPlayer {
    nonisolated static let sampleRate = 44_100.0

    private let engine = AVAudioEngine()
    private let music = AVAudioPlayerNode()
    private let sfx = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: AudioPlayer.sampleRate, channels: 1)
    private var hitBuffers: [Judgement: AVAudioPCMBuffer] = [:]
    private var ready = false

    init() {
        guard let format else { return }
        engine.attach(music)
        engine.attach(sfx)
        engine.connect(music, to: engine.mainMixerNode, format: format)
        engine.connect(sfx, to: engine.mainMixerNode, format: format)
        for j in [Judgement.perfect, .good] {
            hitBuffers[j] = Self.buffer(Synth.hitSound(j, sampleRate: Self.sampleRate), format: format)
        }
    }

    private static func buffer(_ samples: [Float], format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buf.floatChannelData?[0] else { return nil }
        buf.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { src in
            if let base = src.baseAddress { channel.update(from: base, count: samples.count) }
        }
        return buf
    }

    private func startEngine() -> Bool {
        if engine.isRunning { return true }
        do {
            let session = AVAudioSession.sharedInstance()
            // 遊ぶ人が自分で曲を始めるので、消音スイッチでも鳴らす。ほかのアプリの音は止めない
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            try engine.start()
            ready = true
        } catch {
            ready = false
        }
        return ready
    }

    /// startTime（CACurrentMediaTime の秒）に曲の頭が来るように鳴らす
    func play(_ samples: [Float], at startTime: Double) {
        guard let format, startEngine(), let buf = Self.buffer(samples, format: format) else { return }
        music.stop()
        music.scheduleBuffer(buf, at: nil, options: [])
        let host = AVAudioTime.hostTime(forSeconds: max(startTime, CACurrentMediaTime() + 0.05))
        music.play(at: AVAudioTime(hostTime: host))
        if !sfx.isPlaying { sfx.play() }
    }

    func hit(_ j: Judgement) {
        guard ready, let buf = hitBuffers[j] else { return }
        sfx.scheduleBuffer(buf, at: nil, options: [.interrupts])
        if !sfx.isPlaying { sfx.play() }
    }

    func stop() {
        music.stop()
        sfx.stop()
        engine.stop()
        ready = false
    }
}
