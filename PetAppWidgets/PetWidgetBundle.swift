//
//  PetWidgetBundle.swift
//  PetAppWidgets
//
//  @main for the Widget Extension target. Xcode creates this target's own
//  @main entry point when you add the extension — replace its generated
//  bundle file with this one (or merge the WidgetBundle contents in).
//

import WidgetKit
import SwiftUI

@main
struct PetWidgetBundle: WidgetBundle {
    var body: some Widget {
        LockScreenPetWidget()
        QuestionReadyWidget()
        StreakWidget()
        MemoriesSavedWidget()
        FeedLiveActivityWidget()
    }
}
