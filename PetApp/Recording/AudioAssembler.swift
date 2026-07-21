//
//  AudioAssembler.swift
//  PetApp
//
//  Stitches a draft's ordered audio segments into a single m4a file (KAN-20).
//  A draft can have several segments (recording resumed across app sessions);
//  a saved memory is one continuous file.
//

import AVFoundation

enum AudioAssembler {

    enum AssemblyError: Error { case noTrack, exportFailed }

    /// Concatenates `segmentURLs` in order into a single m4a at `outputURL`.
    static func assemble(segmentURLs: [URL], to outputURL: URL) async throws {
        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw AssemblyError.noTrack
        }

        var cursor = CMTime.zero
        for url in segmentURLs where FileManager.default.fileExists(atPath: url.path) {
            let asset = AVURLAsset(url: url)
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            guard let source = audioTracks.first else { continue }
            let duration = try await asset.load(.duration)
            guard duration.isValid, duration > .zero else { continue }
            try track.insertTimeRange(CMTimeRange(start: .zero, duration: duration),
                                      of: source, at: cursor)
            cursor = cursor + duration
        }

        try? FileManager.default.removeItem(at: outputURL)
        guard let export = AVAssetExportSession(asset: composition,
                                                presetName: AVAssetExportPresetAppleM4A) else {
            throw AssemblyError.exportFailed
        }
        try await export.export(to: outputURL, as: .m4a)
    }
}
