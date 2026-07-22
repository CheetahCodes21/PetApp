//
//  DailyPrompts.swift
//  PetApp
//
//  The daily question shown on the home screen. Questions come in two layers:
//
//  * Anchors — a light, everyday yes/no opener ("Did you go outside today?").
//    Answering "yes" leads to a small, specific follow-up that invites a story;
//    "no" gently falls back to a reflection question instead of pressing on.
//  * Reflections — the deeper, nostalgic prompts. They are the "no" fallback,
//    and can also stand alone as a slower, more contemplative question.
//
//  Whichever branch the user takes, the flow resolves to a single question
//  string that is handed to the recorder unchanged.
//
//  ┌───────────────────────────────────────────────────────────────────────┐
//  │  EDITING THE QUESTION SET                                               │
//  │  This file is the single source of truth for the daily questions.       │
//  │  To add / change / reword questions, edit `anchors` and `reflections`   │
//  │  below — nothing else needs to change. This is intentionally isolated   │
//  │  and low-merge-risk, so the wording can be updated freely over time.    │
//  │  See DailyPrompts.md (same folder) for the how-to and conventions.      │
//  └───────────────────────────────────────────────────────────────────────┘
//

import Foundation

/// A daily "anchor" question: a yes/no opener plus the follow-up asked when the
/// answer is yes. A "no" answer is handled by the caller falling back to a
/// reflection prompt, so no second yes/no layer is needed.
struct DailyPrompt: Identifiable, Equatable {
    let id: String
    /// The light yes/no opener, e.g. "Did you go outside today?"
    let anchor: String
    /// The specific follow-up asked when the user answers yes, phrased so it can
    /// stand on its own as the recorded question, e.g. "Where did you go today?"
    let followUpYes: String
}

enum DailyPrompts {

    /// Everyday openers — the daily driver. Grounded in ordinary, recent life so
    /// they stay easy to answer day after day.
    static let anchors: [DailyPrompt] = [
        DailyPrompt(id: "outside",
                    anchor: "Did you go outside today?",
                    followUpYes: "Where did you go, and how was the weather?"),
        DailyPrompt(id: "food",
                    anchor: "Did you have something good to eat today?",
                    followUpYes: "What was it, and who made it?"),
        DailyPrompt(id: "talk",
                    anchor: "Did you talk with anyone today?",
                    followUpYes: "Who was it, and what did you talk about?"),
        DailyPrompt(id: "smile",
                    anchor: "Did anything make you smile today?",
                    followUpYes: "What was it?"),
        DailyPrompt(id: "watch-listen",
                    anchor: "Did you watch or listen to anything today?",
                    followUpYes: "What was it, and did you enjoy it?"),
        DailyPrompt(id: "sleep",
                    anchor: "Did you sleep well last night?",
                    followUpYes: "Did you dream about anything?"),
        DailyPrompt(id: "loved-ones",
                    anchor: "Did you see family or a friend today?",
                    followUpYes: "Who did you see, and what did you do together?"),
        DailyPrompt(id: "little-jobs",
                    anchor: "Did you get any little jobs done today?",
                    followUpYes: "What did you get to?"),
    ]

    /// Deeper, nostalgic prompts. Used as the gentle "no" fallback, and good as
    /// a standalone slower question.
    static let reflections: [String] = [
        "What made you smile today?",
        "What is a favourite memory from your childhood?",
        "Who is someone you are grateful for?",
        "What is a song that means a lot to you?",
        "Where is a place you have always loved?",
        "What is something kind you did or saw recently?",
        "What is a meal that reminds you of home?",
        "What is a small thing that brought you joy today?",
        "Tell a story about a good friend.",
        "What are you looking forward to?",
    ]

    /// Index of the anchor for today, so it stays stable across the day.
    static var todayIndex: Int {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return anchors.isEmpty ? 0 : day % anchors.count
    }

    /// Today's opener, stable across the day.
    static var todayAnchor: DailyPrompt {
        anchors[todayIndex]
    }
}
