//
//  RivePlantView.swift
//  PetApp
//
//  The animated plant companion (Rive). Drives the "PlantController" state
//  machine:
//   • Bool  IsHungry → Hungry9 state (when down to 1 heart / needs watering)
//   • Bool  IsSick   → Sick9 state   (when the watering window lapses)
//   • Trig  Feed     → Feed9 one-shot (played when watered)
//   • Trig  Talk     → Talk9 one-shot
//   • Idle9 is the resting state when healthy.
//  Also recolours the "Body" via data binding.
//
//  Bump `feedToken` / `talkToken` from the parent to play the one-shots once.
//

import SwiftUI
import RiveRuntime
import UIKit

struct RivePlantView: View {
    /// Food-bar hearts (1...3). One heart ⇒ needs watering.
    var hearts: Int = 3
    var isSick: Bool = false
    var color: SwiftUI.Color
    /// Bump to play the Feed (water) one-shot. Bump to play the Talk one-shot.
    var feedToken: Int = 0
    var talkToken: Int = 0

    @StateObject private var model = RiveViewModel(fileName: "plant",
                                                   stateMachineName: "PlantController")
    @State private var binding: RiveDataBindingViewModel.Instance?

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
            .onChange(of: isSick) { _, _ in applyInputs() }
            .onChange(of: color) { _, _ in applyColor() }
            .onChange(of: feedToken) { _, _ in triggerWater() }
            .onChange(of: talkToken) { _, _ in model.triggerInput("Talk") }
    }

    private func applyInputs() {
        model.setInput("IsHungry", value: hearts <= 1)
        model.setInput("IsSick", value: isSick)
    }

    private func applyColor() {
        binding?.colorProperty(fromPath: "Body")?.value = UIColor(color)
    }

    /// Plays the water/feed animation and clears hungry/sick states.
    private func triggerWater() {
        model.triggerInput("Feed")
        model.setInput("IsHungry", value: false)
        model.setInput("IsSick", value: false)
    }
}
