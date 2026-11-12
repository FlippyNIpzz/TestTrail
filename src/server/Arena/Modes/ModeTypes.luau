--!strict

export type ModeContext = {
	Bounds: BasePart,
	RuntimeFolder: Folder,
	HazardsFolder: Folder,
	OresFolder: Folder,
	DropsFolder: Folder,
	BossesFolder: Folder,
	RegisterOre: (ore: BasePart, id: string) -> (),
	SpawnOreAt: (bounds: BasePart, id: string, position: Vector3) -> BasePart?,
}

export type ArenaModeHandler = {
	Start: (context: ModeContext) -> (),
	Step: (now: number, dt: number) -> (),
	Stop: () -> (),
}

return {}
