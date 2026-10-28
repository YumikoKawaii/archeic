import SwiftUI

enum Theme {
    static let bg = Color(red: 0.055, green: 0.059, blue: 0.075)
    static let surface = Color(red: 0.102, green: 0.11, blue: 0.133)
    static let raised = Color(red: 0.149, green: 0.161, blue: 0.192)
    static let muted = Color(red: 0.639, green: 0.659, blue: 0.706)
    static let accent = Color(red: 0.541, green: 0.706, blue: 0.973)
    static let accent2 = Color(red: 0.773, green: 0.541, blue: 0.976)
    static let accent3 = Color(red: 0.973, green: 0.541, blue: 0.659)
    static let danger = Color(red: 0.949, green: 0.545, blue: 0.51)

    static let gradient = LinearGradient(colors: [accent, accent2, accent3], startPoint: .topLeading, endPoint: .bottomTrailing)
}

extension View {
    func card(radius: CGFloat = 16) -> some View {
        clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

func plural(_ n: Int, _ word: String) -> String {
    "\(n) \(word)\(n == 1 ? "" : "s")"
}

func countLabel(_ items: [Media]) -> String {
    let videos = items.filter(\.isVideo).count
    let photos = items.count - videos
    var parts: [String] = []
    if photos > 0 { parts.append(plural(photos, "photo")) }
    if videos > 0 { parts.append(plural(videos, "video")) }
    return parts.isEmpty ? "Empty" : parts.joined(separator: " · ")
}

struct DaySection: Identifiable {
    let label: String
    let items: [Media]
    var id: String { label }
}

func groupByDay(_ items: [Media]) -> [DaySection] {
    var out: [DaySection] = []
    for m in items {
        let label = m.createTime.map(dayLabel) ?? "Undated"
        if let last = out.last, last.label == label {
            out[out.count - 1] = DaySection(label: label, items: last.items + [m])
        } else {
            out.append(DaySection(label: label, items: [m]))
        }
    }
    return out
}

private func dayLabel(_ d: Date) -> String {
    let cal = Calendar.current
    if cal.isDateInToday(d) { return "Today" }
    if cal.isDateInYesterday(d) { return "Yesterday" }
    let days = cal.dateComponents([.day], from: cal.startOfDay(for: d), to: cal.startOfDay(for: .now)).day ?? 0
    if days < 7 { return d.formatted(.dateTime.weekday(.wide)) }
    if cal.isDate(d, equalTo: .now, toGranularity: .year) { return d.formatted(.dateTime.day().month(.wide)) }
    return d.formatted(.dateTime.day().month(.wide).year())
}
