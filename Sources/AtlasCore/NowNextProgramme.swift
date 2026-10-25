import Foundation

/// The two programme slots shown in the compact channel overview.
public struct NowNextProgramme: Sendable, Equatable {
    public let current: Programme?
    public let next: Programme?

    public init(current: Programme?, next: Programme?) {
        self.current = current
        self.next = next
    }

    /// Chooses the programme covering `date` and the first later programme.
    /// Invalid intervals are ignored, and input ordering is not significant.
    public static func selection(from programmes: [Programme], at date: Date) -> Self {
        let ordered = programmes
            .filter(isValidInterval)
            .sorted { lhs, rhs in
                lhs.start == rhs.start ? lhs.id < rhs.id : lhs.start < rhs.start
            }
        let current = ordered.first { $0.start <= date && date < $0.end }
        let next = ordered.first { $0.start > date }
        return Self(current: current, next: next)
    }

    /// Returns the earliest valid programme start or end strictly after `date`.
    public static func nextTransition(in programmes: [Programme], after date: Date) -> Date? {
        guard date.timeIntervalSinceReferenceDate.isFinite else { return nil }

        return programmes
            .filter(isValidInterval)
            .flatMap { [$0.start, $0.end] }
            .filter { $0 > date }
            .min()
    }

    private static func isValidInterval(_ programme: Programme) -> Bool {
        programme.start.timeIntervalSinceReferenceDate.isFinite
            && programme.end.timeIntervalSinceReferenceDate.isFinite
            && programme.end > programme.start
    }
}
