/// H264StreamParser.swift
/// Low-latency Annex-B H.264 parser for iOS VideoToolbox.
///
/// Converts a raw byte stream (start codes 00 00 01 or 00 00 00 01)
/// into VideoToolbox CMVideoFormatDescription and CMSampleBuffers.

import AVFoundation
import Foundation
import VideoToolbox

/// Parses a continuous stream of raw H.264 Annex-B data into displayable sample buffers.
final class H264StreamParser {
    /// Callback triggered whenever a complete video frame has been parsed and is ready for display.
    var onFrameReady: ((CMSampleBuffer) -> Void)?

    private var formatDescription: CMVideoFormatDescription?
    private var buffer = Data()
    private var currentSPS: Data?
    private var currentPPS: Data?
    private var lastPTS: CMTime = .zero
    private var frameCount: Int64 = 0

    // MARK: - Public API

    /// Appends new bytes from the network to the parser's internal buffer.
    func process(data: Data) {
        buffer.append(data)
        extractNALUnits()
    }

    // MARK: - Annex-B Parsing Logic

    private func extractNALUnits() {
        while buffer.count > 4 {
            // Find the first start code
            guard let firstStart = findStartCode(in: buffer) else { return }
            
            // If the start code is not at the beginning, trim garbage
            if firstStart.index > buffer.startIndex {
                buffer.removeSubrange(..<firstStart.index)
                continue
            }
            
            let naluStart = buffer.index(firstStart.index, offsetBy: firstStart.length)
            
            // Find the next start code to determine the end of this NALU
            if let nextStart = findStartCode(in: buffer[naluStart...]) {
                let naluData = buffer[naluStart ..< nextStart.index]
                handleNALU(Data(naluData))
                
                // Remove the processed NALU, keeping the next start code
                buffer.removeSubrange(..<nextStart.index)
            } else {
                // We have the start but not the end yet. Wait for more data.
                return
            }
        }
    }

    /// Generic helper to find the first H.264 start code (00 00 01 or 00 00 00 01)
    private func findStartCode<C: RandomAccessCollection>(in data: C) -> (index: C.Index, length: Int)? 
    where C.Element == UInt8 {
        guard data.count >= 3 else { return nil }
        
        var i = data.startIndex
        let limit = data.index(data.endIndex, offsetBy: -3)
        
        while i <= limit {
            if data[i] == 0 && data[data.index(after: i)] == 0 {
                let third = data[data.index(i, offsetBy: 2)]
                if third == 1 {
                    return (i, 3)
                } else if third == 0 {
                    let fourthIdx = data.index(i, offsetBy: 3)
                    if fourthIdx < data.endIndex && data[fourthIdx] == 1 {
                        return (i, 4)
                    }
                }
            }
            i = data.index(after: i)
        }
        return nil
    }

    private func handleNALU(_ data: Data) {
        guard !data.isEmpty else { return }
        let naluType = data[0] & 0x1F
        
        switch naluType {
        case 7: // SPS
            if currentSPS != data {
                print("H264Parser: Received SPS (\(data.count) bytes)")
                currentSPS = data
                refreshFormatDescription()
            }
        case 8: // PPS
            if currentPPS != data {
                print("H264Parser: Received PPS (\(data.count) bytes)")
                currentPPS = data
                refreshFormatDescription()
            }
        case 5: // IDR (I-Frame)
            createSampleBuffer(from: data)
        case 1: // Non-IDR (P-Frame)
            // Only log every 30 frames for P-frames to avoid log spam
            createSampleBuffer(from: data)
        default:
            // Skip AUD, SEI, etc.
            break
        }
    }

    // MARK: - VideoToolbox Integration

    private func refreshFormatDescription() {
        guard let sps = currentSPS, let pps = currentPPS else { return }

        sps.withUnsafeBytes { spsBytes in
            pps.withUnsafeBytes { ppsBytes in
                let parameterPointers = [
                    spsBytes.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    ppsBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
                ]
                let parameterSizes = [spsBytes.count, ppsBytes.count]

                var description: CMFormatDescription?
                let status = CMVideoFormatDescriptionCreateFromH264ParameterSets(
                    allocator: kCFAllocatorDefault,
                    parameterSetCount: 2,
                    parameterSetPointers: parameterPointers,
                    parameterSetSizes: parameterSizes,
                    nalUnitHeaderLength: 4,
                    formatDescriptionOut: &description
                )

                if status == noErr {
                    print("H264Parser: Format description created successfully")
                    self.formatDescription = description
                } else {
                    print("H264Parser: Failed to create format description: \(status)")
                }
            }
        }
    }

    private func createSampleBuffer(from naluData: Data) {
        guard let formatDescription = formatDescription else { 
            print("H264Parser: Dropping frame - no format description yet")
            return 
        }

        let naluLength = naluData.count
        let totalSize = naluLength + 4
        var avccLength = UInt32(naluLength).bigEndian

        var blockBuffer: CMBlockBuffer?
        var status = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: totalSize,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: totalSize,
            flags: 0,
            blockBufferOut: &blockBuffer
        )

        guard status == noErr, let buffer = blockBuffer else { 
            print("H264Parser: Failed to create block buffer: \(status)")
            return 
        }

        // Copy length prefix
        status = CMBlockBufferReplaceDataBytes(
            with: &avccLength,
            blockBuffer: buffer,
            offsetIntoDestination: 0,
            dataLength: 4
        )
        guard status == noErr else { return }

        // Copy NALU data
        naluData.withUnsafeBytes { bytes in
            _ = CMBlockBufferReplaceDataBytes(
                with: bytes.baseAddress!,
                blockBuffer: buffer,
                offsetIntoDestination: 4,
                dataLength: naluLength
            )
        }

        // For zero-latency real-time streaming, we need a valid host-relative timestamp.
        // We use the host clock for the first frame, then increment it to ensure 
        // perfect monotonicity even if network delivery is jittery.
        if frameCount == 0 {
            lastPTS = CMClockGetTime(CMClockGetHostTimeClock())
        } else {
            let frameDuration = CMTime(value: 3000, timescale: 90000) // 30 fps
            lastPTS = CMTimeAdd(lastPTS, frameDuration)
        }
        frameCount += 1

        var timingInfo = CMSampleTimingInfo(
            duration: CMTime(value: 3000, timescale: 90000),
            presentationTimeStamp: lastPTS,
            decodeTimeStamp: .invalid
        )

        var sampleBuffer: CMSampleBuffer?
        let sampleStatus = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: buffer,
            formatDescription: formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingInfo,
            sampleSizeEntryCount: 1,
            sampleSizeArray: [totalSize],
            sampleBufferOut: &sampleBuffer
        )

        if sampleStatus == noErr, let sb = sampleBuffer {
            CMSetAttachment(
                sb,
                key: kCMSampleAttachmentKey_DisplayImmediately,
                value: kCFBooleanTrue,
                attachmentMode: kCMAttachmentMode_ShouldPropagate
            )
            onFrameReady?(sb)
        } else {
            print("H264Parser: Failed to create sample buffer: \(sampleStatus)")
        }
    }
}
