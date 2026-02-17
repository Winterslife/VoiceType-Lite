import AVFoundation
import Foundation

final class AudioRecorder {
    private var audioEngine: AVAudioEngine?
    private var audioBuffer: [Float] = []
    private let bufferLock = NSLock()
    private let sampleRate: Double = 16000.0

    var isRecording: Bool { audioEngine != nil }

    func startRecording() throws {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )!

        let converter = AVAudioConverter(from: inputFormat, to: targetFormat)!

        bufferLock.lock()
        audioBuffer = []
        bufferLock.unlock()

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }

            let frameCount = AVAudioFrameCount(
                Double(buffer.frameLength) * self.sampleRate / inputFormat.sampleRate
            )
            guard frameCount > 0,
                  let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount)
            else { return }

            var error: NSError?
            var isDone = false
            converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                if isDone {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                isDone = true
                outStatus.pointee = .haveData
                return buffer
            }

            guard error == nil, let channelData = convertedBuffer.floatChannelData else { return }

            let samples = Array(UnsafeBufferPointer(
                start: channelData[0],
                count: Int(convertedBuffer.frameLength)
            ))

            self.bufferLock.lock()
            self.audioBuffer.append(contentsOf: samples)
            self.bufferLock.unlock()
        }

        engine.prepare()
        try engine.start()
        audioEngine = engine
    }

    func stopRecordingAndGetWAV() -> Data? {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil

        bufferLock.lock()
        let samples = audioBuffer
        audioBuffer = []
        bufferLock.unlock()

        guard !samples.isEmpty else { return nil }
        return buildWAVData(samples: samples, sampleRate: Int(sampleRate))
    }

    // MARK: - WAV Builder

    private func buildWAVData(samples: [Float], sampleRate: Int) -> Data {
        let int16Samples = samples.map { sample -> Int16 in
            let clamped = max(-1.0, min(1.0, sample))
            return Int16(clamped * Float(Int16.max))
        }

        let dataSize = int16Samples.count * 2
        let fileSize = 36 + dataSize

        var data = Data()
        data.reserveCapacity(44 + dataSize)

        // RIFF header
        data.append(contentsOf: [UInt8]("RIFF".utf8))
        data.append(contentsOf: withUnsafeBytes(of: UInt32(fileSize).littleEndian) { Array($0) })
        data.append(contentsOf: [UInt8]("WAVE".utf8))

        // fmt chunk
        data.append(contentsOf: [UInt8]("fmt ".utf8))
        data.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })        // chunk size
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })         // PCM format
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })         // mono
        data.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) }) // sample rate
        let byteRate = UInt32(sampleRate * 2)
        data.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })           // byte rate
        data.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian) { Array($0) })          // block align
        data.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) })         // bits per sample

        // data chunk
        data.append(contentsOf: [UInt8]("data".utf8))
        data.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Array($0) })

        for sample in int16Samples {
            data.append(contentsOf: withUnsafeBytes(of: sample.littleEndian) { Array($0) })
        }

        return data
    }
}
