extends RefCounted

const LIQUID_IDS := ["acid", "water", "oil"]
const KINDS := {
	"water": {"name": "Acqua", "color": Color("389ed2"), "edge": Color("b2e9fa"), "fall": 1.0, "spread": 0.2, "damage": 0.0},
	"acid": {"name": "Acido", "color": Color("85c638"), "edge": Color("e0f58a"), "fall": 0.7, "spread": 0.12, "damage": 28.0},
	"oil": {"name": "Petrolio", "color": Color("3d344b"), "edge": Color("ba91c4"), "fall": 0.15, "spread": 0.04, "damage": 4.0},
	"gas": {"name": "Gas", "color": Color("cfaa64"), "edge": Color("f7dc9e")}
}
