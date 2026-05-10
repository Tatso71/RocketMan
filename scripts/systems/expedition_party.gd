extends RefCounted
class_name ExpeditionParty

const MAX_MEMBERS := 3
var members: Array[String] = []

func add_member(species_id: String) -> bool:
	if members.size() >= MAX_MEMBERS:
		return false
	members.append(species_id)
	return true
