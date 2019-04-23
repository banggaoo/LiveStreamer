import Foundation
import AVFoundation

public protocol AVMixerRecorderDelegate: class {
    var moviesDirectory: URL { get }
    func rotateFile(_ recorder: AVMixerRecorder, withPresentationTimeStamp: CMTime, mediaType: AVMediaType)
    func getPixelBufferAdaptor(_ recorder: AVMixerRecorder, withWriterInput: AVAssetWriterInput?) -> AVAssetWriterInputPixelBufferAdaptor?
    func getWriterInput(_ recorder: AVMixerRecorder, mediaType: AVMediaType, sourceFormatHint: CMFormatDescription?) -> AVAssetWriterInput?
    func didStartRunning(_ recorder: AVMixerRecorder)
    func didStopRunning(_ recorder: AVMixerRecorder)
    func didFinishWriting(_ recorder: AVMixerRecorder)
}

public protocol AVMixerRecorderOuterDelegate: class {
    func didFinishWriting(_ recorder: AVMixerRecorder)
    func didStartRunning(_ recorder: AVMixerRecorder)
}

public class AVMixerRecorder: NSObject {

    public static let defaultOutputSettings: [AVMediaType: [String: Any]] = [
        .audio: [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 0,
            AVNumberOfChannelsKey: 0
        ],
        .video: [
            AVVideoCodecKey: AVVideoCodecH264,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 1024 * 1024 * 1],
            AVVideoHeightKey: 0,
            AVVideoWidthKey: 0
        ]
    ]

    public var writer: AVAssetWriter?
    public var fileName: String?
    private var recorderDelegate: DefaultAVMixerRecorderDelegate
    public weak var delegate: AVMixerRecorderDelegate?  // remove weak for saving delegate
    public weak var outerDelegate: AVMixerRecorderOuterDelegate?
    public var writerInputs: [AVMediaType: AVAssetWriterInput] = [:]
    public var outputSettings: [AVMediaType: [String: Any]] = AVMixerRecorder.defaultOutputSettings
    public var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    public let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.AVMixerRecorder.lock")
    private(set) var running: Bool = false
    fileprivate(set) var sourceTime: CMTime = CMTime.zero

    var isReadyForStartWriting: Bool {
        guard let writer: AVAssetWriter = writer else { return false }
        return outputSettings.count == writer.inputs.count
    }

    public override init() {
        recorderDelegate = DefaultAVMixerRecorderDelegate()
        super.init()
        delegate = recorderDelegate
    }

    // Movie Creator
    // In appendSampleBuffer from VideoIOComponent , you can create original
    final func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer, mediaType: AVMediaType) {
        lockQueue.async {
            guard let delegate: AVMixerRecorderDelegate = self.delegate, self.running else { return }

            delegate.rotateFile(self, withPresentationTimeStamp: sampleBuffer.presentationTimeStamp, mediaType: mediaType)

            guard
                let writer: AVAssetWriter = self.writer,
                let input: AVAssetWriterInput = delegate.getWriterInput(self, mediaType: mediaType, sourceFormatHint: sampleBuffer.formatDescription),
                self.isReadyForStartWriting else {
                return
            }

            switch writer.status {
            case .unknown:
                writer.startWriting()
                
                // For remove black screen in the beginning
                let startTimeToUse : CMTime = CMTimeAdd(self.sourceTime, CMTimeMakeWithSeconds(0.5, preferredTimescale: 1000000000))
                
                writer.startSession(atSourceTime: startTimeToUse)

            default:
                break
            }

            if input.isReadyForMoreMediaData {
                input.append(sampleBuffer)
            }
        }
    }
    
    final func appendPixelBuffer(_ pixelBuffer: CVPixelBuffer, withPresentationTime: CMTime) {
        lockQueue.async {
            guard let delegate: AVMixerRecorderDelegate = self.delegate, self.running else { return }

            delegate.rotateFile(self, withPresentationTimeStamp: withPresentationTime, mediaType: .video)
            guard
                let writer = self.writer,
                let input = delegate.getWriterInput(self, mediaType: .video, sourceFormatHint: CMVideoFormatDescription.create(pixelBuffer: pixelBuffer)),
                let adaptor = delegate.getPixelBufferAdaptor(self, withWriterInput: input),
                self.isReadyForStartWriting else {
                return
            }

            switch writer.status {
            case .unknown:
                writer.startWriting()
                
                let startTimeToUse : CMTime = CMTimeAdd(self.sourceTime, CMTimeMakeWithSeconds(0.5, preferredTimescale: 1000000000))

                writer.startSession(atSourceTime: startTimeToUse)
            default:
                break
            }

            if input.isReadyForMoreMediaData {
                adaptor.append(pixelBuffer, withPresentationTime: withPresentationTime)
            }
        }
    }

    func finishWriting() {
        guard let writer: AVAssetWriter = writer, writer.status == .writing else { return }
        
        for (_, input) in writerInputs {
            input.markAsFinished()
        }
        writer.finishWriting {
            self.outerDelegate?.didFinishWriting(self)
            self.writer = nil
            self.writerInputs.removeAll()
            self.pixelBufferAdaptor = nil
        }
    }
}

extension AVMixerRecorder: Running {
    // MARK: Running
    final func startRunning() {
        lockQueue.async {
            guard !self.running else {
                return
            }
            self.running = true
            self.outerDelegate?.didStartRunning(self)
        }
    }

    final func stopRunning() {
        lockQueue.async {
            guard self.running else {
                return
            }
            self.finishWriting()
            self.running = false
            self.delegate?.didStopRunning(self)
        }
    }
}

// MARK: -
public class DefaultAVMixerRecorderDelegate: NSObject {
    public var duration: Int64 = 0
    public var dateFormat: String = "-yyyyMMdd-HHmmss"

    private var rotateTime: CMTime = CMTime.zero
    private var clockReference: AVMediaType = .video

    public override init () {
        super.init()
        
    }

    #if os(iOS)
    public lazy var moviesDirectory: URL = {
        return URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
    }()
    #else
    public lazy var moviesDirectory: URL = {
        return URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.moviesDirectory, .userDomainMask, true)[0])
    }()
    #endif
}

extension DefaultAVMixerRecorderDelegate: AVMixerRecorderDelegate {
    // MARK: AVMixerRecorderDelegate
    public func rotateFile(_ recorder: AVMixerRecorder, withPresentationTimeStamp: CMTime, mediaType: AVMediaType) {
        guard clockReference == mediaType && rotateTime.value < withPresentationTimeStamp.value else {
            return
        }
        if recorder.writer != nil {
            recorder.finishWriting()
        }
        recorder.writer = createWriter(recorder.fileName)
        recorder.writer?.shouldOptimizeForNetworkUse = true
        rotateTime = CMTimeAdd(
            withPresentationTimeStamp,
            CMTimeMake(value: duration == 0 ? .max : duration * Int64(withPresentationTimeStamp.timescale), timescale: withPresentationTimeStamp.timescale)
        )
        recorder.sourceTime = withPresentationTimeStamp
    }

    public func getPixelBufferAdaptor(_ recorder: AVMixerRecorder, withWriterInput: AVAssetWriterInput?) -> AVAssetWriterInputPixelBufferAdaptor? {
        guard recorder.pixelBufferAdaptor == nil else {
            return recorder.pixelBufferAdaptor
        }
        guard let writerInput: AVAssetWriterInput = withWriterInput else {
            return nil
        }
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: [: ])
        recorder.pixelBufferAdaptor = adaptor
        return adaptor
    }

    public func getWriterInput(_ recorder: AVMixerRecorder, mediaType: AVMediaType, sourceFormatHint: CMFormatDescription?) -> AVAssetWriterInput? {
        guard recorder.writerInputs[mediaType] == nil else {
            return recorder.writerInputs[mediaType]
        }

        var outputSettings: [String: Any] = [: ]
        if let defaultOutputSettings: [String: Any] = recorder.outputSettings[mediaType] {
            switch mediaType {
            case .audio:
                guard
                    let format: CMAudioFormatDescription = sourceFormatHint,
                    let inSourceFormat: AudioStreamBasicDescription = format.streamBasicDescription?.pointee else {
                    break
                }
                for (key, value) in defaultOutputSettings {
                    switch key {
                    case AVSampleRateKey:
                        outputSettings[key] = AnyUtil.isZero(value) ? inSourceFormat.mSampleRate : value
                    case AVNumberOfChannelsKey:
                        outputSettings[key] = AnyUtil.isZero(value) ? Int(inSourceFormat.mChannelsPerFrame) : value
                    default:
                        outputSettings[key] = value
                    }
                }
            case .video:
                guard let format: CMVideoFormatDescription = sourceFormatHint else {
                    break
                }
                for (key, value) in defaultOutputSettings {
                    switch key {
                    case AVVideoHeightKey:
                        outputSettings[key] = AnyUtil.isZero(value) ? Int(format.dimensions.height) : value
                    case AVVideoWidthKey:
                        outputSettings[key] = AnyUtil.isZero(value) ? Int(format.dimensions.width) : value
                    default:
                        outputSettings[key] = value
                    }
                }
            default:
                break
            }
        }

        let input: AVAssetWriterInput = AVAssetWriterInput(mediaType: mediaType, outputSettings: outputSettings, sourceFormatHint: sourceFormatHint)
        input.expectsMediaDataInRealTime = true
        recorder.writerInputs[mediaType] = input
        recorder.writer?.add(input)

        return input
    }

    public func didFinishWriting(_ recorder: AVMixerRecorder) {
    }

    public func didStartRunning(_ recorder: AVMixerRecorder) {
    }

    public func didStopRunning(_ recorder: AVMixerRecorder) {
        rotateTime = CMTime.zero
    }

    private func createWriter(_ fileName: String?) -> AVAssetWriter? {
        guard let fileName: String = fileName else { return nil }
        let url: URL = moviesDirectory.appendingPathComponent(fileName + ".mp4")

        do {
            try FileManager.default.removeItem(at: url)
            let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
            return writer
        } catch {
            printLog("\(error)")
        }
        return nil
    }
}
