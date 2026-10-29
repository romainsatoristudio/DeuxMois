import EventKit
import OSLog
import SwiftUI

extension Calendar {
    /// Calendrier courant, avec la langue du Mac (jours et mois en français).
    static var display: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.locale = .autoupdatingCurrent
        return calendar
    }

    /// Initiales des jours (L M M J V S D) en commençant par le premier jour de la semaine local.
    var weekdayInitials: [String] {
        let symbols = veryShortStandaloneWeekdaySymbols
        let first = firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    func isWeekend(column: Int) -> Bool {
        let weekday = (firstWeekday - 1 + column) % 7 + 1
        return weekday == 1 || weekday == 7
    }
}

// MARK: - Jours fériés

enum FrenchHolidays {
    private static let fixed = [(1, 1), (5, 1), (5, 8), (7, 14), (8, 15), (11, 1), (11, 11), (12, 25)]
    /// Lundi de Pâques, Ascension, lundi de Pentecôte.
    private static let afterEaster = [1, 39, 50]

    static func contains(_ date: Date, calendar: Calendar = .display) -> Bool {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return false }
        if fixed.contains(where: { $0 == (month, day) }) { return true }
        let easter = easterSunday(year: year, calendar: calendar)
        let offset = calendar.dateComponents([.day], from: easter, to: calendar.startOfDay(for: date)).day
        return offset.map(afterEaster.contains) ?? false
    }

    /// Algorithme de Meeus/Jones/Butcher (calendrier grégorien).
    private static func easterSunday(year: Int, calendar: Calendar) -> Date {
        let a = year % 19, b = year / 100, c = year % 100
        let d = b / 4, e = b % 4, f = (b + 8) / 25, g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4, k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = (h + l - 7 * m + 114) % 31 + 1
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}

// MARK: - Événements

/// Couleurs des calendriers qui ont un événement, par jour (clé : début du jour).
typealias EventDots = [Date: [Color]]

enum EventDotsLoader {
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "DeuxMois", category: "events")

    static var hasAccess: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }

    /// Événements du mois de `today` et du suivant, avec une semaine de marge de chaque côté.
    static func load(around today: Date, calendar: Calendar = .display) -> EventDots {
        guard hasAccess else {
            log.debug("Pas d'accès au Calendrier")
            return [:]
        }
        let month = calendar.dateInterval(of: .month, for: today)!.start
        let start = calendar.date(byAdding: .day, value: -7, to: month)!
        let end = calendar.date(byAdding: DateComponents(month: 2, day: 7), to: month)!
        let store = EKEventStore()
        let events = store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: nil))

        var calendarsByDay: [Date: [EKCalendar]] = [:]
        for event in events {
            var day = calendar.startOfDay(for: max(event.startDate, start))
            let last = min(event.endDate, end)
            repeat {
                if !calendarsByDay[day, default: []].contains(where: { $0.calendarIdentifier == event.calendar.calendarIdentifier }) {
                    calendarsByDay[day, default: []].append(event.calendar)
                }
                day = calendar.date(byAdding: .day, value: 1, to: day)!
            } while day < last
        }

        let familyCount = store.calendars(for: .event).filter(isFamily).count
        log.debug("\(events.count) événements, \(calendarsByDay.count) jours marqués, \(familyCount) calendrier(s) famille")

        // Le calendrier familial passe en premier, les autres par ordre alphabétique.
        return calendarsByDay.mapValues { calendars in
            calendars
                .sorted { (isFamily($0) ? 0 : 1, $0.title) < (isFamily($1) ? 0 : 1, $1.title) }
                .map { isFamily($0) ? Color.yellow : Color(cgColor: $0.cgColor) }
        }
    }

    private static func isFamily(_ calendar: EKCalendar) -> Bool {
        calendar.title.localizedCaseInsensitiveContains("famil")
    }
}
