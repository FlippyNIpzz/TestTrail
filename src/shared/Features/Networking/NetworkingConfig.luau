--!strict

-- Central registry. Add channels only when a feature defines their payload contract.
return {
    FolderName = "FoundationRemotes",
    Remotes = {
        ["Admin.GetState"] = { ClassName = "RemoteFunction", Feature = "Admin" },
        ["Admin.Prepare"] = { ClassName = "RemoteFunction", Feature = "Admin" },
        ["Admin.Commit"] = { ClassName = "RemoteFunction", Feature = "Admin" },
        ["Base.GetState"] = { ClassName = "RemoteFunction", Feature = "Base" },
        ["Base.PurchaseLevel"] = { ClassName = "RemoteFunction", Feature = "Base" },
        ["UI.GetState"] = { ClassName = "RemoteFunction", Feature = "UI" },
        ["Inventory.Sell"] = { ClassName = "RemoteFunction", Feature = "Inventory" },
        ["UI.StateChanged"] = { ClassName = "RemoteEvent", Feature = "UI" },
    },
}
