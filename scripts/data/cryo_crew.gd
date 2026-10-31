extends RefCounted

const MEMBERS := [
	{"id": "biomedical", "name": "Scienziato biomedico", "species": "human", "role": "Scienza, tecnica e biomedicina", "color": Color("85bdde")},
	{"id": "botanist", "name": "Scienziata botanica", "species": "human", "role": "Vegetazione, agricoltura e chimica", "color": Color("a0d89b")},
	{"id": "cat", "name": "Gatto", "species": "cat", "role": "Gatto. Nessuna specializzazione richiesta.", "color": Color("edbd83")}
]

static func capsule(index: int) -> Rect2:
	return Rect2(-140 + index * 73, -304, 64, 100)
