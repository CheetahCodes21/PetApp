//
//  RiveCatView.swift
//  PetApp
//
//  The animated cat companion (Rive). Drives the "CatController" state machine:
//   • Bool  IsHungry  → Hungry9 state  (when down to 1 heart)
//   • Bool  IsSick    → Sick9 state
//   • Trig  Feed      → Feed9 one-shot (then back to Idle9)
//   • Trig  Talk      → Talking9 one-shot
//   • Idle9 is the resting state when not hungry / sick.
//  Also recolours the "Body" via data binding.
//
//  The one-shot animations (Feed / Talk) are fired by bumping `feedToken` /
//  `talkToken` from the parent — each change to the token plays the animation
//  once.
//

import SwiftUI
import RiveRuntime
import UIKit

struct RiveCatView: View {
    /// Food-bar hearts (1...3). One heart ⇒ hungry.
    var hearts: Int = 3
    var isSick: Bool = false
    var color: SwiftUI.Color
    /// Bump to play the Feed one-shot. Bump to play the Talk one-shot.
    var feedToken: Int = 0
    var talkToken: Int = 0

    @StateObject private var model = RiveViewModel(fileName: "cat",
                                                   stateMachineName: "CatController")
    @State private var binding: RiveDataBindingViewModel.Instance?

    var body: some View {
        model.view()
            .onAppear {
                // Fill the frame (crop the empty artboard margins) so the cat
                // itself is as large as possible within its square.
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
            .onChange(of: feedToken) { _, _ in triggerFeed() }
            .onChange(of: talkToken) { _, _ in model.triggerInput("Talk") }
    }

    private func applyInputs() {
        model.setInput("IsHungry", value: hearts <= 1)
        model.setInput("IsSick", value: isSick)
    }

    private func applyColor() {
        binding?.colorProperty(fromPath: "Body")?.value = UIColor(color)
    }

    /// Plays the feed animation and clears hungry/sick states.
    func triggerFeed() {
        model.triggerInput("Feed")
        model.setInput("IsHungry", value: false)
        model.setInput("IsSick", value: false)
    }
}
