import SwiftUI
import WidgetKit

/// Taille d'affichage, choisie selon la famille du widget.
struct CalendarStyle {
    var titleSize: CGFloat
    var daySize: CGFloat
    var spacing: CGFloat
    /// Écart entre le chiffre et les points : assez grand, les points passent sous le rond du jour.
    var dotGap: CGFloat = 1

    static let compact = CalendarStyle(titleSize: 11, daySize: 10, spacing: 12)
    static let regular = CalendarStyle(titleSize: 13, daySize: 11, spacing: 8, dotGap: 2)
    static let large = CalendarStyle(titleSize: 15, daySize: 14, spacing: 24, dotGap: 3)
    static let roomy = CalendarStyle(titleSize: 13, daySize: 12, spacing: 0, dotGap: 2)
    static let extraRoomy = CalendarStyle(titleSize: 18, daySize: 17, spacing: 0, dotGap: 3.5)
}

/// Le mois de `today` et le mois suivant, côte à côte ou l'un sous l'autre.
struct TwoMonthsView: View {
    var today: Date
    var events: EventDots = [:]
    var vertical = false
    var style = CalendarStyle.compact

    var body: some View {
        let calendar = Calendar.display
        let thisMonth = calendar.dateInterval(of: .month, for: today)!.start
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: thisMonth)!
        if vertical {
            // Une seule pile : toutes les semaines des deux mois ont la même hauteur.
            VStack(spacing: 0) {
                MonthView(month: thisMonth, today: today, events: events, style: style, onlyUsedWeeks: true)
                Color.clear.frame(height: style.spacing)
                MonthView(month: nextMonth, today: today, events: events, style: style, onlyUsedWeeks: true, showWeekdays: false)
            }
        } else {
            HStack(alignment: .top, spacing: style.spacing) {
                VStack(spacing: 0) { MonthView(month: thisMonth, today: today, events: events, style: style) }
                VStack(spacing: 0) { MonthView(month: nextMonth, today: today, events: events, style: style) }
            }
        }
    }
}

struct MonthView: View {
    var month: Date
    var today: Date
    var events: EventDots
    var style: CalendarStyle
    /// Sinon toujours 6 semaines, pour que deux mois côte à côte restent alignés.
    var onlyUsedWeeks = false
    var showWeekdays = true

    /// Titre puis lignes de la grille, sans pile : c'est la vue parente qui les empile.
    var body: some View {
        let calendar = Calendar.display
        let isCurrentMonth = calendar.isDate(month, equalTo: today, toGranularity: .month)
        Group {
            CalendarTitle(text: Text(monthName(month, today: today, calendar: calendar))
                .foregroundStyle(isCurrentMonth ? Color.red : Color.primary), style: style)
            WeekGrid(weeks: weeks(calendar), today: today, events: events, style: style, showWeekdays: showWeekdays)
        }
    }

    /// Semaines du mois, `nil` pour les cases hors du mois.
    private func weeks(_ calendar: Calendar) -> [[Date?]] {
        let count = calendar.range(of: .day, in: .month, for: month)!.count
        let offset = (calendar.component(.weekday, from: month) - calendar.firstWeekday + 7) % 7
        var cells = [Date?](repeating: nil, count: offset)
        cells += (0..<count).map { calendar.date(byAdding: .day, value: $0, to: month) }
        let total = onlyUsedWeeks ? (cells.count + 6) / 7 * 7 : 42
        cells += [Date?](repeating: nil, count: total - cells.count)
        return stride(from: 0, to: total, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }
}

/// Les 5 semaines à partir de la semaine en cours : pas de coupure en fin de mois.
struct FiveWeeksView: View {
    var today: Date
    var events: EventDots = [:]
    var style = CalendarStyle.compact

    var body: some View {
        let calendar = Calendar.display
        let start = calendar.dateInterval(of: .weekOfYear, for: today)!.start
        let days = (0..<35).map { calendar.date(byAdding: .day, value: $0, to: start)! }
        let months = days.map { calendar.dateInterval(of: .month, for: $0)!.start }
            .reduce(into: [Date]()) { if $0.last != $1 { $0.append($1) } }
        let title = months.enumerated().reduce(Text("")) { text, item in
            let name = Text(monthName(item.element, today: today, calendar: calendar))
                .foregroundStyle(calendar.isDate(item.element, equalTo: today, toGranularity: .month) ? Color.red : Color.primary)
            return item.offset == 0 ? name : text + Text(" – ").foregroundStyle(.secondary) + name
        }
        VStack(spacing: 0) {
            CalendarTitle(text: title, style: style)
            WeekGrid(
                weeks: stride(from: 0, to: 35, by: 7).map { days[$0..<$0 + 7].map(Optional.some) },
                today: today, events: events, style: style, boldFirstOfMonth: true
            )
        }
    }
}

private func monthName(_ month: Date, today: Date, calendar: Calendar) -> String {
    let locale = calendar.locale ?? .autoupdatingCurrent
    let sameYear = calendar.isDate(month, equalTo: today, toGranularity: .year)
    let format = sameYear ? Date.FormatStyle().month(.wide) : Date.FormatStyle().month(.wide).year()
    return month.formatted(format.locale(locale)).capitalized(with: locale)
}

private struct CalendarTitle: View {
    var text: Text
    var style: CalendarStyle

    var body: some View {
        text
            .font(.system(size: style.titleSize, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .widgetAccentable()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 2)
            .padding(.bottom, 2)
    }
}

// MARK: - Grille

/// En-tête des jours puis une ligne par semaine, précédée de son numéro.
/// Sans pile, comme `MonthView` : les lignes se partagent la hauteur de la vue parente.
struct WeekGrid: View {
    var weeks: [[Date?]]
    var today: Date
    var events: EventDots
    var style: CalendarStyle
    var boldFirstOfMonth = false
    var showWeekdays = true

    var body: some View {
        let calendar = Calendar.display
        Group {
            if showWeekdays {
                row(weekNumber: nil) {
                    ForEach(Array(calendar.weekdayInitials.enumerated()), id: \.offset) { index, symbol in
                        Text(symbol)
                            .font(.system(size: style.daySize * 0.8, weight: .semibold))
                            .foregroundStyle(calendar.isWeekend(column: index) ? .tertiary : .secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, style.daySize * 0.25)
            }
            ForEach(weeks.indices, id: \.self) { index in
                let week = weeks[index]
                row(weekNumber: week.lazy.compactMap { $0 }.first.map { calendar.component(.weekOfYear, from: $0) }) {
                    ForEach(week.indices, id: \.self) { column in
                        Group {
                            if let day = week[column] {
                                DayCell(
                                    day: day,
                                    today: today,
                                    dots: events[calendar.startOfDay(for: day)] ?? [],
                                    weekend: calendar.isWeekend(column: column),
                                    emphasized: boldFirstOfMonth && calendar.component(.day, from: day) == 1,
                                    style: style
                                )
                            } else {
                                Color.clear
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
    }

    private func row(weekNumber: Int?, @ViewBuilder cells: () -> some View) -> some View {
        HStack(spacing: 0) {
            Text(weekNumber.map(String.init) ?? "")
                .font(.system(size: style.daySize * 0.7, weight: .medium).monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: style.daySize * 1.3, alignment: .leading)
                .frame(maxHeight: .infinity)
            cells()
        }
    }
}

struct DayCell: View {
    var day: Date
    var today: Date
    var dots: [Color]
    var weekend: Bool
    var emphasized: Bool
    var style: CalendarStyle

    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        let calendar = Calendar.display
        let isToday = calendar.isDate(day, inSameDayAs: today)
        let dotSize = max(3, style.daySize * 0.3)
        VStack(spacing: style.dotGap) {
            Text("\(calendar.component(.day, from: day))")
                .font(.system(size: style.daySize, weight: isToday || emphasized ? .bold : .medium).monospacedDigit())
                .foregroundStyle(foreground(isToday: isToday))
                .lineLimit(1)
                .background {
                    marker(isToday: isToday, holiday: FrenchHolidays.contains(day, calendar: calendar))
                        .frame(width: style.daySize * 1.45, height: style.daySize * 1.45)
                }
            HStack(spacing: dotSize * 0.5) {
                ForEach(dots.prefix(3).indices, id: \.self) { index in
                    Circle().fill(dots[index]).frame(width: dotSize, height: dotSize)
                }
            }
            .frame(height: dotSize)
        }
    }

    private func foreground(isToday: Bool) -> AnyShapeStyle {
        if isToday { return AnyShapeStyle(renderingMode == .fullColor ? Color.white : Color.primary) }
        return weekend ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary)
    }

    /// Rond rouge pour aujourd'hui, contour gris pour les jours fériés.
    @ViewBuilder
    private func marker(isToday: Bool, holiday: Bool) -> some View {
        if isToday && renderingMode == .fullColor {
            Circle().fill(Color.red)
        } else if isToday {
            Circle().strokeBorder(Color.primary, lineWidth: 1.5).widgetAccentable()
        } else if holiday {
            Circle().strokeBorder(Color.gray, lineWidth: 1)
        }
    }
}
