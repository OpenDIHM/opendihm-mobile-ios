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

    // MARK: - Public API

    /// Appends new bytes from the network to the parser's internal buffer.
    /// - Parameter data: Raw bytes received from the TCP stream.
    func process(data: Data) {
        buffer.append(data)
        extractNALUnits()
    }

    // MARK: - Annex-B Parsing Logic

    private func extractNALUnits() {
        // H.264 Start Codes: 0x000001 (3-byte) or 0x00000001 (4-byte)
        // We look for the 4-byte variant as standard in libcamera-vid.
        let startCode = Data([0x00, 0x00, 0x00, 0x01])

        while true {
            guard buffer.count > 4 else { return }

            // Find the start of the current NALU
            guard let range = buffer.range(of: startCode) else {
                // No more start codes found in current buffer
                return
            }

            // Find the start of the NEXT NALU to define the end of the current one
            let remaining = buffer.advanced(by: range.upperBound)
            if let nextRange = remaining.range(of: startCode) {
                // We have a full NALU between range.upperBound and nextRange.lowerBound
                let naluData = buffer.subdata(in: range.upperBound ..< (range.upperBound + nextRange.lowerBound))

                handleNALU(naluData)

                // Advance the buffer
                buffer.removeSubrange(0 ..< (range.upperBound + nextRange.lowerBound))
            } else {
                // Incomplete NALU, wait for more data from network
                return
            }
        }
    }

    private func handleNALU(_ data: Data) {
        // NALU Header byte: [Forbidden (1 bit) | NRI (2 bits) | Type (5 bits)]
        let naluType = data[0] & 0x1F

        switch naluType {
        case 7: // SPS (Sequence Parameter Set)
            updateFormatDescription(sps: data)
        case 8: // PPS (Picture Parameter Set)
            updatePPS(pps: data)
        case 1, 5: // P-Frame or I-Frame
            createSampleBuffer(from: data)
        default:
            break
        }
    }

    // MARK: - VideoToolbox Integration

    private var currentSPS: Data?
    private var currentPPS: Data?

    private func updateFormatDescription(sps: Data) {
        currentSPS = sps
        refreshFormatDescription()
    }

    private func updatePPS(pps: Data) {
        currentPPS = pps
        refreshFormatDescription()
    }

    private func refreshFormatDescription() {
        guard let sps = currentSPS, let pps = currentPPS else { return }

        let parameterPointers = [
            sps.withUnsafeBytes { $0.baseAddress!.assumingType(of: UInt8.self) },
            pps.withUnsafeBytes { $0.baseAddress!.assumingType(of: UInt8.self) }
        ]
        let parameterSizes = [sps.count, pps.count]

        let status = CMVideoFormatDescriptionCreateFromH264ParameterSets(
            allocator: kCFAllocatorDefault,
            parameterSetCount: 2,
            parameterSetPointers: parameterPointers,
            parameterSetSizes: parameterSizes,
            nalUnitHeaderLength: 4,
            formatDescriptionOut: &formatDescription
        )

        if status != noErr {
            print("H264Parser: Failed to create format description: \(status)")
        }
    }

    private func createSampleBuffer(from naluData: Data) {
        guard let formatDescription = formatDescription else { return }

        // VideoToolbox expects NALUs to be prefixed with their length (AVCC format)
        // instead of the Annex-B start codes.
        var length = UInt32(naluData.count).bigEndian
        var avccData = Data()
        avccData.append(UnsafeBufferPointer(start: &length, count: 1))
        avccData.append(naluData)

        var blockBuffer: CMBlockBuffer?
        let status = avccData.withUnsafeBytes { bytes in
            CMBlockBufferCreateWithMemoryBlock(
                allocator: kCFAllocatorDefault,
                memoryBlock: UnsafeMutableRawPointer(mutating: bytes.baseAddress!),
                blockLength: avccData.count,
                blockAllocator: kCFAllocatorNull,
                customBlockSource: nil,
                offsetToData: 0,
                dataLength: avccData.count,
                flags: 0,
                blockBufferOut: &blockBuffer
            )
        }

        guard status == noErr, let buffer = blockBuffer else { return }

        var sampleBuffer: CMSampleBuffer?
        let sampleSize = avccData.count
        let sampleStatus = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: buffer,
            formatDescription: formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 0,
            sampleTimingArray: nil,
            sampleSizeEntryCount: 1,
            sampleSizeArray: [sampleSize],
            sampleBufferOut: &sampleBuffer
        )

        if sampleStatus == noErr, let sb = sampleBuffer {
            onFrameReady?(sb)
        }
    }
}
