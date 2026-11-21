extends RefCounted

const LEVEL_GROWTH := 1.5
const DEPTH_GROWTH := 2.2
const CORE := Vector2(-72, 0)
const NODES := {
	&"power": {"title":"Puissance hydraulique", "short":"Puissance", "stat":&"power", "step":15, "max":3, "cost":30, "depth":0, "pos":Vector2(-57,-70), "requires":{}},
	&"cadence": {"title":"Cadence", "short":"Cadence", "stat":&"cadence", "step":12, "max":3, "cost":30, "depth":0, "pos":Vector2(17,-116), "requires":{}},
	&"power_advanced": {"title":"Puissance hydraulique avancée", "short":"Puissance II", "stat":&"power", "step":15, "max":3, "cost":55, "depth":3, "pos":Vector2(106,-144), "requires":{&"power":3, &"cadence":2}},
	&"range": {"title":"Portée", "short":"Portée", "stat":&"range", "step":15, "max":3, "cost":35, "depth":0, "pos":Vector2(11,-29), "requires":{}},
	&"rotation": {"title":"Rotation", "short":"Rotation", "stat":&"cadence", "step":10, "max":3, "cost":55, "depth":1, "pos":Vector2(102,-69), "requires":{&"range":1}},
	&"range_advanced": {"title":"Portée avancée", "short":"Portée II", "stat":&"range", "step":15, "max":3, "cost":55, "depth":3, "pos":Vector2(197,-105), "requires":{&"range":3, &"rotation":2}},
	&"armor": {"title":"Blindage", "short":"Blindage", "stat":&"armor", "step":20, "max":3, "cost":25, "depth":0, "pos":Vector2(11,45), "requires":{}},
	&"armor_advanced": {"title":"Blindage avancé", "short":"Blindage II", "stat":&"armor", "step":20, "max":3, "cost":55, "depth":3, "pos":Vector2(112,67), "requires":{&"armor":3}},
	&"logistics": {"title":"Logistique", "short":"Logistique", "stat":&"armor", "step":8, "max":3, "cost":50, "depth":1, "pos":Vector2(87,-5), "requires":{&"range":1, &"armor":1}},
	&"cannon_four": {"title":"Achats groupés", "short":"Achats", "stat":&"discount", "step":10, "max":1, "cost":250, "depth":2, "pos":Vector2(179,-20), "requires":{&"logistics":1, &"power":3, &"range":2}},
	&"pressure": {"title":"Réserve de pression", "short":"Pression", "stat":&"power", "step":10, "max":3, "cost":35, "depth":2, "pos":Vector2(227,47), "requires":{&"cannon_four":1}},
	&"cannon_five": {"title":"Réseau de collecte", "short":"Collecte", "stat":&"income", "step":15, "max":1, "cost":600, "depth":4, "pos":Vector2(190,122), "requires":{&"pressure":3, &"cannon_four":1}},
	&"reserve": {"title":"Équipe de réserve", "short":"Réserve", "stat":&"cadence", "step":10, "max":3, "cost":48, "depth":2, "pos":Vector2(103,145), "requires":{&"cannon_five":1}},
	&"cannon_six": {"title":"Fonds de départ", "short":"Fonds", "stat":&"startup", "step":25, "max":1, "cost":1200, "depth":6, "pos":Vector2(16,148), "requires":{&"reserve":3, &"cannon_five":1}},
	&"village": {"title":"Résilience du village", "short":"Résilience", "stat":&"village", "step":20, "max":3, "cost":35, "depth":0, "pos":Vector2(-154,12), "requires":{}},
	&"reinforcement": {"title":"Renforts du village", "short":"Renforts", "stat":&"village", "step":12, "max":3, "cost":55, "depth":1, "pos":Vector2(-220,-48), "requires":{&"village":1}},
	&"village_advanced": {"title":"Résilience avancée", "short":"Résilience II", "stat":&"village", "step":20, "max":3, "cost":55, "depth":3, "pos":Vector2(-224,-130), "requires":{&"village":3, &"reinforcement":2}},
}

const EFFECTS := {
	&"power":"Puissance d’extinction des canons", &"range":"Portée de détection et du jet",
	&"cadence":"Vitesse de rotation des canons", &"armor":"PV maximum des canons",
	&"village":"PV maximum du village", &"discount":"Réduit le prix des canons", &"income":"Augmente les revenus de la partie", &"startup":"Ajoute des crédits au début de la partie",
}

# Prix effectivement utilisés au jalon 5, uniquement pour la migration.
const LEGACY_COSTS := {&"power":30, &"range":35, &"cadence":30, &"armor":25, &"deployment":100, &"village":35}


static func cost(id: StringName, level: int) -> int:
	var node: Dictionary = NODES[id]
	if node.max == 1:
		return node.cost
	return roundi(node.cost * pow(LEVEL_GROWTH, level) * pow(DEPTH_GROWTH, node.depth))
