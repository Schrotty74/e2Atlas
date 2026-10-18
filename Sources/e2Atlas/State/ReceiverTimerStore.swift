import Foundation
import Observation
import AtlasCore
import AtlasReceiver

@MainActor @Observable
final class ReceiverTimerStore {
    private(set) var timers: [ReceiverTimer] = []
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var error: String?
    private(set) var notice: String?
    @ObservationIgnored private var generation = UUID()

    func load(using client: OpenWebifClient?) async {
        let token = UUID(); generation = token
        guard let client else { timers = []; isLoading = false; error = "Kein Receiver ausgewählt."; return }
        isLoading = true; error = nil
        do {
            let values = try await client.timers()
            guard token == generation, !Task.isCancelled else { return }
            timers = values.sorted { $0.begin < $1.begin }; isLoading = false
        } catch is CancellationError { }
        catch {
            guard token == generation, !Task.isCancelled else { return }
            self.error = error.localizedDescription; isLoading = false
        }
    }

    func save(_ draft: ReceiverTimerDraft, editing timer: ReceiverTimer?, using client: OpenWebifClient?) async -> Bool {
        guard let client else { error = "Kein Receiver ausgewählt."; return false }
        guard draft.end > draft.begin else { error = "Die Endzeit muss nach der Startzeit liegen."; return false }
        isSaving = true; error = nil; notice = nil
        do {
            if let timer { try await client.editTimer(timer, with: draft) }
            else { try await client.addTimer(draft) }
            isSaving = false; notice = timer == nil ? "Timer wurde hinzugefügt." : "Timer wurde geändert."
            await load(using: client)
            return true
        } catch is CancellationError { isSaving = false; return false }
        catch { isSaving = false; self.error = error.localizedDescription; return false }
    }

    func delete(_ timer: ReceiverTimer, using client: OpenWebifClient?) async -> Bool {
        guard let client else { error = "Kein Receiver ausgewählt."; return false }
        isSaving = true; error = nil; notice = nil
        do {
            try await client.deleteTimer(timer)
            isSaving = false; notice = "Timer wurde gelöscht."
            await load(using: client)
            return true
        } catch is CancellationError { isSaving = false; return false }
        catch { isSaving = false; self.error = error.localizedDescription; return false }
    }

    func overlaps(_ draft: ReceiverTimerDraft, excluding timer: ReceiverTimer? = nil) -> [ReceiverTimer] {
        timers.filter { candidate in
            candidate.id != timer?.id && !candidate.disabled && !candidate.cancelled
                && candidate.end > Date() && candidate.begin < draft.end && candidate.end > draft.begin
        }
    }

    func reset() { generation = UUID(); timers = []; isLoading = false; isSaving = false; error = nil; notice = nil }
}
