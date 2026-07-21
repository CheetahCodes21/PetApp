//
//  RecordingView.swift
//  PetApp
//
//  The main recording screen (KAN-19 "Record my answer"). One large control to
//  start, an unmistakable recording state with a live level meter and elapsed
//  timer, and pause / resume / start-over. Tuned for an older-adult audience:
//  large targets, text labels on every control, no icon-only actions.
//
//  Boundary note: this screen owns *capturing* audio only. When the user keeps a
//  recording it hands the finished `RecordingDraft` to `onFinish`; what happens
//  next (the completion / save sheet) is layered on by the save-memory flow
//  (KAN-20) via `RecordingIntegration`, so this screen stays self-contained.
//

import SwiftUI
import UIKit

struct RecordingView: View {
    /// The journalling question being answered, shown for context.
    var question: String?
    /// A recovered draft to continue, appending a new segment; nil starts fresh.
    var resuming: RecordingDraft?
    /// Called with the finished draft when the user chooses to keep it. The
    /// caller decides what to do next (KAN-20 opens the save sheet).
    var onFinish: (RecordingDraft) -> Void
    /// Called when the user backs out without keeping anything.
    var onCancel: () -> Void

    @StateObject private var recorder = AudioRecorder()
    @State private var showStartOverConfirm = false

    var body: some View {
        ZStack {
            AppColor.screenBackground.ignoresSafeArea()

            if recorder.micPermissionDenied {
                permissionDeniedView
            } else {
                recordingContent
            }
        }
        .interactiveDismissDisabled(hasAudio)
        .task {
            // Start immediately when the screen appears so the user only taps
            // once. A recovered draft is continued; otherwise a fresh recording
            // begins (the mic-permission prompt appears here on first use).
            if let resuming {
                await recorder.resumeRecovered(resuming)
            } else if recorder.phase == .idle {
                await recorder.start(question: question)
            }
        }
        .onDisappear { recorder.teardown() }
        .alert("Start over?", isPresented: $showStartOverConfirm) {
            Button("Keep recording", role: .cancel) {}
            Button("Start over", role: .destructive) { recorder.discard() }
        } message: {
            Text("This deletes what you have recorded so far. This can't be undone.")
        }
    }

    private var recordingContent: some View {
        VStack(spacing: Spacing.lg) {
            header
            Spacer(minLength: Spacing.md)
            timerLabel
            LevelMeterView(level: recorder.level,
                           isActive: recorder.phase == .recording)
                .frame(height: 72)
                .padding(.horizontal, Spacing.lg)
            statusLabel
            if let error = recorder.errorMessage {
                errorBanner(error)
            }
            Spacer(minLength: Spacing.md)
            controls
        }
        .padding(Spacing.lg)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button("Close") { closeTapped() }
                .font(.title3.weight(.medium))
                .foregroundStyle(AppColor.textSecondary)
            Spacer()
        }
        .overlay(alignment: .center) {
            if let question, !question.isEmpty {
                Text(question)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppColor.textPrimary)
                    .padding(.horizontal, Spacing.xl)
            }
        }
    }

    // MARK: - Timer & status

    private var timerLabel: some View {
        Text(Self.timeString(recorder.elapsed))
            .font(.system(size: 56, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(AppColor.textPrimary)
            .accessibilityLabel("Recording length")
            .accessibilityValue(Self.spokenTime(recorder.elapsed))
            .accessibilityAddTraits(.updatesFrequently)
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch recorder.phase {
        case .recording:
            label("Recording", color: AppColor.ninja)
        case .paused:
            label("Paused", color: AppColor.textSecondary)
        case .interrupted:
            label("Paused for a call. Ready when you are.", color: AppColor.textSecondary)
        case .preparing:
            label("Getting ready…", color: AppColor.textSecondary)
        case .finished:
            label("Saved", color: AppColor.success)
        default:
            Color.clear.frame(height: 1)
        }
    }

    private func label(_ text: String, color: Color) -> some View {
        HStack(spacing: Spacing.xs) {
            if recorder.phase == .recording {
                Circle().fill(color).frame(width: 12, height: 12)
            }
            Text(text)
                .font(.title3.weight(.medium))
                .foregroundStyle(color)
        }
        .padding(.top, Spacing.xs)
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.body)
            .foregroundStyle(AppColor.textPrimary)
            .multilineTextAlignment(.center)
            .padding(Spacing.md)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppColor.thistle.opacity(0.5))
            )
    }

    // MARK: - Microphone permission (KAN-8, US-004 AC4)

    /// Shown when the microphone permission is denied: a plain explanation and a
    /// single button to open Settings — nothing else to distract or block.
    private var permissionDeniedView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 52))
                .foregroundStyle(AppColor.textSecondary)
            Text("Recording needs the microphone")
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppColor.textPrimary)
            Text("To record your memories in your own voice, turn on the microphone for MemoMe in Settings.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppColor.textSecondary)
            Spacer()
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(FilledButtonStyle(background: AppColor.ninja))
            Button("Not now") { onCancel() }
                .buttonStyle(OutlinedButtonStyle())
        }
        .padding(Spacing.lg)
    }

    // MARK: - Controls

    @ViewBuilder
    private var controls: some View {
        switch recorder.phase {
        case .idle, .preparing, .failed, .finished:
            Button {
                Task { await recorder.start(question: question) }
            } label: {
                Label("Record", systemImage: "mic.fill")
            }
            .buttonStyle(FilledButtonStyle(background: AppColor.ninja))
            .disabled(recorder.phase == .preparing)

        case .recording:
            VStack(spacing: Spacing.sm) {
                Button("Pause") { recorder.pause() }
                    .buttonStyle(FilledButtonStyle(background: AppColor.ninja))
                Button("Start over", role: .destructive) { showStartOverConfirm = true }
                    .buttonStyle(OutlinedButtonStyle())
            }

        case .paused:
            VStack(spacing: Spacing.sm) {
                Button("Continue recording") { recorder.resume() }
                    .buttonStyle(FilledButtonStyle(background: AppColor.ninja))
                if canSave {
                    Button("Save as a memory") { finishTapped() }
                        .buttonStyle(FilledButtonStyle(background: AppColor.success))
                } else {
                    tooShortHint
                }
                Button("Start over", role: .destructive) { showStartOverConfirm = true }
                    .buttonStyle(OutlinedButtonStyle())
            }

        case .interrupted:
            VStack(spacing: Spacing.sm) {
                Button("Resume") { recorder.resume() }
                    .buttonStyle(FilledButtonStyle(background: AppColor.ninja))
                if canSave {
                    Button("Save as a memory") { finishTapped() }
                        .buttonStyle(OutlinedButtonStyle())
                } else {
                    tooShortHint
                }
            }
        }
    }

    /// A memory needs at least the minimum length; until then, saving is
    /// replaced by a gentle hint so the recording can never be lost on save.
    private var canSave: Bool {
        recorder.elapsed >= RecordingLimits.minimumDuration
    }

    private var tooShortHint: some View {
        Text("Keep going — a memory needs at least 10 seconds.")
            .font(.callout)
            .foregroundStyle(AppColor.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.vertical, Spacing.xs)
    }

    // MARK: - Actions

    private var hasAudio: Bool {
        switch recorder.phase {
        case .recording, .paused, .interrupted: return true
        default: return false
        }
    }

    private func finishTapped() {
        if let draft = recorder.finish() {
            onFinish(draft)   // caller opens the save sheet (KAN-20)
        }
    }

    private func closeTapped() {
        if hasAudio {
            showStartOverConfirm = true
        } else {
            onCancel()
        }
    }

    // MARK: - Formatting

    static func timeString(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    static func spokenTime(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let minutes = total / 60
        let seconds = total % 60
        if minutes == 0 { return "\(seconds) seconds" }
        return "\(minutes) minutes \(seconds) seconds"
    }
}

// MARK: - Level meter

/// A simple waveform-style level meter driven by the recorder's live level.
struct LevelMeterView: View {
    var level: Float
    var isActive: Bool

    private let barCount = 24

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 4) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(isActive ? AppColor.ninja : AppColor.textSecondary.opacity(0.3))
                        .frame(height: barHeight(index: index, maxHeight: geo.size.height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .animation(.easeOut(duration: 0.08), value: level)
        }
        .accessibilityHidden(true)
    }

    private func barHeight(index: Int, maxHeight: CGFloat) -> CGFloat {
        let minHeight: CGFloat = 4
        guard isActive else { return minHeight }
        // Shape the level across the row so the centre is tallest.
        let centre = Double(barCount - 1) / 2
        let distance = abs(Double(index) - centre) / centre
        let shaped = CGFloat(level) * (1.0 - CGFloat(distance) * 0.5)
        return max(minHeight, shaped * maxHeight)
    }
}

#Preview {
    RecordingView(question: "What is a place that always makes you feel calm?",
                  onFinish: { _ in },
                  onCancel: {})
}
