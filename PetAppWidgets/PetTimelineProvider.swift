//
//  PetTimelineProvider.swift
//  PetAppWidgets
//

import WidgetKit

struct PetEntry: TimelineEntry {
    let date: Date
    let data: PetWidgetData
}

struct PetTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PetEntry {
        PetEntry(date: .now, data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (PetEntry) -> Void) {
        completion(PetEntry(date: .now, data: PetWidgetStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PetEntry>) -> Void) {
        let entry = PetEntry(date: .now, data: PetWidgetStore.load())
        // The app should also call WidgetCenter.shared.reloadAllTimelines()
        // right after any state change (new daily question, feed action, new
        // memory saved) so widgets update immediately instead of waiting.
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}
