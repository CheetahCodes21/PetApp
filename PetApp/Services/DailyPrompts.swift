//
//  DailyPrompts.swift
//  PetApp
//
//  Gentle daily prompt questions shown on the home screen.
//

import Foundation

enum DailyPrompts {
    static let all: [String] = [
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

    /// Index of the prompt for today, so it stays stable across the day.
    static var todayIndex: Int {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return all.isEmpty ? 0 : day % all.count
    }
}
