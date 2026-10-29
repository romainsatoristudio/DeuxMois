import SwiftUI
import WidgetKit

struct DayEntry: TimelineEntry {
    let date: Date
    var events: EventDots = [:]
}

/// Une entrée maintenant et une à minuit ; rechargement toutes les 30 min pour suivre le Calendrier.
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> DayEntry { DayEntry(date: .now) }

    func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> Void) {
        completion(DayEntry(date: .now, events: EventDotsLoader.load(around: .now)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
        let calendar = Calendar.display
        let now = Date.now
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        let entries = [now, midnight].map { DayEntry(date: $0, events: EventDotsLoader.load(around: $0)) }
        let reload = min(midnight, now.addingTimeInterval(30 * 60))
        completion(Timeline(entries: entries, policy: .after(reload)))
    }
}

struct DeuxMoisWidgetView: View {
    var entry: DayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemLarge:
            TwoMonthsView(today: entry.date, events: entry.events, vertical: true, style: .regular)
        case .systemExtraLarge:
            TwoMonthsView(today: entry.date, events: entry.events, style: .large)
        default:
            TwoMonthsView(today: entry.date, events: entry.events, style: .compact)
        }
    }
}

struct FiveWeeksWidgetView: View {
    var entry: DayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemMedium:
            FiveWeeksView(today: entry.date, events: entry.events, style: .roomy)
        case .systemLarge:
            FiveWeeksView(today: entry.date, events: entry.events, style: .extraRoomy)
        default:
            FiveWeeksView(today: entry.date, events: entry.events)
        }
    }
}

struct DeuxMoisWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DeuxMoisWidget", provider: Provider()) { entry in
            DeuxMoisWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Deux mois")
        .description("Le mois en cours et le mois suivant, pour voir d'un coup d'œil quel jour tombe une date.")
        .supportedFamilies([.systemMedium, .systemLarge, .systemExtraLarge])
    }
}

struct CinqSemainesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CinqSemainesWidget", provider: Provider()) { entry in
            FiveWeeksWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Cinq semaines")
        .description("La semaine en cours et les quatre suivantes, sans coupure en fin de mois.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct DeuxMoisWidgets: WidgetBundle {
    var body: some Widget {
        DeuxMoisWidget()
        CinqSemainesWidget()
    }
}
