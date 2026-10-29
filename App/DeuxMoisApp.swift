import EventKit
import SwiftUI
import WidgetKit

/// L'app ne sert qu'à porter les widgets : elle demande l'accès au Calendrier et affiche un aperçu.
@main
struct DeuxMoisApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}

struct ContentView: View {
    @State private var events: EventDots = [:]
    @State private var hasAccess = EventDotsLoader.hasAccess

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Deux mois")
                .font(.title.bold())
            Text("Pour ajouter un widget : clic droit sur le bureau → « Modifier les widgets… », puis cherchez « Deux mois » ou « Cinq semaines ».")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !hasAccess {
                HStack {
                    Text("Sans accès au Calendrier, les widgets n'affichent pas les points d'événements.")
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button("Ouvrir les réglages") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
                    }
                }
            }

            HStack(alignment: .top, spacing: 12) {
                preview(TwoMonthsView(today: .now, events: events), width: 330)
                preview(FiveWeeksView(today: .now, events: events), width: 156)
            }
        }
        .padding(24)
        .frame(width: 546)
        .task { await refresh() }
    }

    private func preview(_ content: some View, width: CGFloat) -> some View {
        content
            .padding(14)
            .frame(width: width, height: 156)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 20))
    }

    private func refresh() async {
        if EKEventStore.authorizationStatus(for: .event) == .notDetermined {
            _ = try? await EKEventStore().requestFullAccessToEvents()
        }
        hasAccess = EventDotsLoader.hasAccess
        events = EventDotsLoader.load(around: .now)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
