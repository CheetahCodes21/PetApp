//
//  RivePlantView.swift
//  PetApp
//
//  The animated plant companion (Rive). Drives the "PlantController" state
//  machine:
//   • Bool  IsHungry → hungry/thirsty state (when down to 1 heart / needs water)
//   • Trig  Feed     → watering one-shot (played when watered)
//   • idle is the resting state when healthy.
//  Also recolours the "Body" via data binding.
//
//  Bump `feedToken` from the parent to play the water one-shot once.
//

import SwiftUI
import RiveRuntime
import UIKit

struct RivePlantView: View {
    /// Food-bar hearts (1...3). One heart ⇒ needs watering.
    var hearts: Int = 3
    var color: SwiftUI.Color
    /// Bump to play the Feed (water) one-shot.
    var feedToken: Int = 0

    /// Roughly how long the Feed one-shot runs. `IsHungry` is held until then
    /// so the watering animation plays out before the plant settles to idle.
    private static let feedDuration: TimeInterval = 1.2

    @StateObject private var model = RiveViewModel(fileName: "plant",
                                                   stateMachineName: "PlantController")
    @State private var binding: RiveDataBindingViewModel.Instance?
    /// True while the Feed one-shot is playing, so hunger isn't cleared mid-frame.
    @State private var isWatering = false

    var body: some View {
        model.view()
            .onAppear {
                model.fit = .cover
                model.alignment = .center
                model.riveModel?.enableAutoBind { instance in
                    binding = instance
                    applyColor()
                }
                applyInputs()
            }
            .onChange(of: hearts) { _, _ in applyInputs() }
            .onChange(of: color) { _, _ in applyColor() }
            .onChange(of: feedToken) { _, _ in triggerWater() }
    }

    private func applyInputs() {
        // While watering, leave IsHungry alone — the Feed one-shot is playing
        // and triggerWater() will clear it once the animation finishes.
        guard !isWatering else { return }
        model.setInput("IsHungry", value: hearts <= 1)
    }

    private func applyColor() {
        binding?.colorProperty(fromPath: "Body")?.value = UIColor(color)
    }

    /// Waters the plant: plays the Feed one-shot, then settles back to idle.
    ///
    /// Hunger is kept set through the animation (so the Feed transition isn't
    /// short-circuited by the Hungry → idle bool transition firing in the same
    /// frame), then cleared once it ends so the plant returns to idle.
    private func triggerWater() {
        isWatering = true
        model.triggerInput("Feed")
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.feedDuration) {
            isWatering = false
            model.setInput("IsHungry", value: false)
        }
    }
}
