import Foundation
#if canImport(CloudKit)
import CloudKit
import OSLog

/// Drives Mac ↔ iPhone sync over the user's private CloudKit database using
/// `CKSyncEngine` (sync-plan.md §2/§7). It owns the engine, persists its serialized
/// state, and bridges both directions:
///
///   • **Local → cloud:** as `LocalChangeSink`, it receives the id-level delta the
///     `TaskStore` computes at each save and enqueues those records to send.
///   • **Cloud → local:** fetched record changes are translated back into `TodoItem`s
///     and funneled through `TaskStore.applyRemoteChanges`, which buffers them to a
///     safe moment so a remote edit never reshuffles a row under the user's hand (P5).
///
/// `importance` is never synced — it's local AI output (sync-plan.md §3); the
/// `TodoItem ↔ CKRecord` mapping it relies on omits it and is already unit-tested.
///
/// IMPORTANT — not yet exercised at runtime. This compiles against the CloudKit SDK,
/// but it can't actually run until the one-time setup in sync-plan.md §6 exists (Apple
/// Developer team signing, the iCloud/CloudKit capability, and the
/// `iCloud.com.smarttdl.SmartTDL` container). Nothing instantiates it until then, so
/// the app stays local-only and unaffected. Wire it up in `SmartTDLApp` once §6 is done.
@available(iOS 17.0, macOS 14.0, *)
final class SyncCoordinator: NSObject, CKSyncEngineDelegate {
    static let containerIdentifier = "iCloud.com.smarttdl.SmartTDL"

    private let store: TaskStore
    private let database: CKDatabase
    private let zoneID = CKRecordZone.ID(
        zoneName: TodoItem.Sync.zoneName, ownerName: CKCurrentUserDefaultName)
    private let stateURL: URL
    private let log = Logger(subsystem: "com.smarttdl.SmartTDL", category: "sync")
    // Set once in init (delegate must be `self`, so it can't be a `let`); never mutated
    // after. `nonisolated(unsafe)` documents that and satisfies the delegate's Sendable.
    nonisolated(unsafe) private var engine: CKSyncEngine!

    /// - Parameters:
    ///   - store: the single source of truth, mutated only on the main actor.
    ///   - container: defaults to the app's CloudKit container; injectable for tests.
    init(store: TaskStore, container: CKContainer = CKContainer(identifier: containerIdentifier)) {
        self.store = store
        self.database = container.privateCloudDatabase
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SmartTDL", isDirectory: true)
        self.stateURL = dir.appendingPathComponent("sync-state.plist")
        super.init()

        let serialized = loadState()
        let config = CKSyncEngine.Configuration(
            database: database, stateSerialization: serialized, delegate: self)
        self.engine = CKSyncEngine(config)

        // First run (no saved state): create our custom zone before anything ships.
        if serialized == nil {
            engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
        }

        // Start mirroring local edits; this also pushes everything already on device.
        Task { @MainActor in store.attachSync(self) }
    }

    // MARK: - CKSyncEngineDelegate

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let e):
            saveState(e.stateSerialization)
        case .accountChange(let e):
            handleAccountChange(e)
        case .fetchedRecordZoneChanges(let e):
            await applyFetched(modifications: e.modifications, deletions: e.deletions)
        case .sentRecordZoneChanges(let e):
            handleSentChanges(e)
        case .fetchedDatabaseChanges(let e):
            handleFetchedDatabaseChanges(e)
        case .willFetchChanges, .didFetchChanges, .willSendChanges, .didSendChanges,
             .willFetchRecordZoneChanges, .didFetchRecordZoneChanges, .sentDatabaseChanges:
            break   // lifecycle bookends — nothing to do
        @unknown default:
            log.debug("Unhandled sync event: \(String(describing: event))")
        }
    }

    /// Build the next batch of records to upload. Records are resolved from the store on
    /// the main actor (as Sendable `TodoItem`s) and turned into `CKRecord`s off-actor, so
    /// no `CKRecord` ever crosses an actor boundary.
    func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let scope = context.options.scope
        let pending = syncEngine.state.pendingRecordZoneChanges.filter { scope.contains($0) }
        guard !pending.isEmpty else { return nil }

        // Snapshot the still-present tasks for the saves in this batch.
        let snapshot: [CKRecord.ID: TodoItem] = await MainActor.run {
            var map: [CKRecord.ID: TodoItem] = [:]
            for change in pending {
                if case .saveRecord(let recordID) = change,
                   let uuid = UUID(uuidString: recordID.recordName),
                   let item = self.store.item(uuid) {
                    map[recordID] = item
                }
            }
            return map
        }

        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { recordID in
            // A save whose task vanished locally before upload is simply dropped.
            snapshot[recordID].map { $0.makeRecord(in: self.zoneID) }
        }
    }

    // MARK: - Cloud → local

    private func applyFetched(
        modifications: [CKDatabase.RecordZoneChange.Modification],
        deletions: [CKDatabase.RecordZoneChange.Deletion]
    ) async {
        let upserts = modifications.compactMap { TodoItem(record: $0.record) }
        let deletes = deletions.compactMap { UUID(uuidString: $0.recordID.recordName) }
        guard !upserts.isEmpty || !deletes.isEmpty else { return }
        await MainActor.run {
            // Buffered + applied at a safe moment inside the store (honors P5).
            store.applyRemoteChanges(upserts: upserts, deletions: deletes)
        }
    }

    private func handleFetchedDatabaseChanges(_ event: CKSyncEngine.Event.FetchedDatabaseChanges) {
        // If our zone was deleted on another device, recreate it and re-push everything.
        let ourZoneDeleted = event.deletions.contains { $0.zoneID == zoneID }
        if ourZoneDeleted {
            log.notice("Tasks zone was deleted remotely — recreating and re-uploading.")
            engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
            Task { @MainActor in store.resyncAll() }
        }
    }

    // MARK: - Send results & account state

    private func handleSentChanges(_ event: CKSyncEngine.Event.SentRecordZoneChanges) {
        for failed in event.failedRecordSaves {
            let recordID = failed.record.recordID
            switch failed.error.code {
            case .serverRecordChanged:
                // The server already has a newer version — LWW: let the fetched copy win.
                // It arrives via fetchedRecordZoneChanges; nothing to re-send here.
                continue
            case .zoneNotFound, .userDeletedZone:
                // Recreate the zone and retry this record.
                engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
                engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
            case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited:
                // Transient — CKSyncEngine retries automatically; just log.
                log.debug("Transient save failure for \(recordID.recordName, privacy: .public)")
            default:
                log.error("Unrecoverable save failure for \(recordID.recordName, privacy: .public): \(failed.error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func handleAccountChange(_ event: CKSyncEngine.Event.AccountChange) {
        switch event.changeType {
        case .signIn:
            // A fresh account — push the whole local store up to it.
            Task { @MainActor in store.resyncAll() }
        case .switchAccounts, .signOut:
            // Local data stays put; we simply stop mirroring to the old account. The
            // engine drops its pending state. (Sign-out path — app remains local-only.)
            log.notice("iCloud account signed out / switched — sync paused, local data intact.")
        @unknown default:
            break
        }
    }

    // MARK: - LocalChangeSink (local → cloud)

    /// Enqueue the id-level delta from a local save as pending CKSyncEngine changes.
    /// Called on the main actor by `TaskStore`; `engine.state` is thread-safe to mutate.
    func localStoreDidChange(upserts: [UUID], deletions: [UUID]) {
        let saves = upserts.map {
            CKSyncEngine.PendingRecordZoneChange.saveRecord(
                CKRecord.ID(recordName: $0.uuidString, zoneID: zoneID))
        }
        let deletes = deletions.map {
            CKSyncEngine.PendingRecordZoneChange.deleteRecord(
                CKRecord.ID(recordName: $0.uuidString, zoneID: zoneID))
        }
        guard !saves.isEmpty || !deletes.isEmpty else { return }
        engine.state.add(pendingRecordZoneChanges: saves + deletes)
    }

    // MARK: - State persistence

    private func loadState() -> CKSyncEngine.State.Serialization? {
        guard let data = try? Data(contentsOf: stateURL) else { return nil }
        return try? PropertyListDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
    }

    private func saveState(_ serialization: CKSyncEngine.State.Serialization) {
        guard let data = try? PropertyListEncoder().encode(serialization) else { return }
        try? data.write(to: stateURL, options: .atomic)
    }
}

@available(iOS 17.0, macOS 14.0, *)
extension SyncCoordinator: LocalChangeSink {}
#endif
