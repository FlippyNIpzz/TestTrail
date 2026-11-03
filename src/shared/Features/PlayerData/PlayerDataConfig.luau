--!strict

return {
    StudioStorageMode = "Memory",
    DevelopmentStore = "Foundation_Development_v1",
    LiveStore = "Foundation_Live_v1",
    AutoSaveSeconds = 120,
    LoadAttempts = 3,
    LoadRetryDelays = { 1, 2 },
    SessionWaitSeconds = 10,
    StorageReadySeconds = 15,
    ShutdownWaitSeconds = 25,
    SaveRetryInitialSeconds = 5,
    SaveRetryMaxSeconds = 60,
    SchemaVersion = 1,
}
