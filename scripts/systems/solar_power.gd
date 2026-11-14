extends RefCounted

const RATE := 0.1
const SIZE := Vector2i(2, 1)

static func placement_blocker(origin: Vector2i, site: RefCounted) -> String:
	if origin.y != -1:
		return "Posa il pannello in superficie, sul terreno e a cielo aperto"
	if origin.x < site.LEFT or origin.x + SIZE.x > site.RIGHT:
		return "Pannello fuori dai confini del pianeta"
	# Reserve the hull, side boosters and landing feet, including their sky column.
	if origin.x < 7 and origin.x + SIZE.x > -7:
		return "Serve cielo libero: sposta il pannello fuori dall'ingombro della nave"
	for x in range(origin.x, origin.x + SIZE.x):
		if site.material(Vector2i(x, 0)).is_empty():
			return "Serve terreno stabile sotto tutto il pannello"
	return ""

static func generating(building: Dictionary, site: RefCounted) -> bool:
	return building.id == "solar_panel" and building.get("state") == "active" \
		and building.get("enabled", true) and not building.get("damaged", false) \
		and placement_blocker(building.origin, site).is_empty()
