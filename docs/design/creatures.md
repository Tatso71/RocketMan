# Specie habitat e cooperazione

Catalogo generato da [creatures.json](../../design/v1/creatures.json). Modificare il JSON e rieseguire `node tools/design/build.mjs`. Numeri di bilanciamento iniziali, da provare nel gioco.

Nessun combattimento. Osservazione → fiducia → trasporto volontario → habitat adatto → aiuto facoltativo. Le capacità delle creature hanno sempre alternative tecnologiche. Nessuna specie crea metalli o cristalli dal nulla.

| ID | Nome | Pianeta | Ambiente | Habitat | Aiuto | Alimento |
| --- | --- | --- | --- | --- | --- | --- |
| species_luccivola | Luccivola | Ocra | flying | Habitat piccolo | ability_light | Biomassa vegetale |
| species_mossback | Mossback | Ocra | ground | Habitat piccolo | ability_support_warning | Biomassa vegetale |
| species_echofin | Echofin | Ocra | amphibious | Habitat piccolo | ability_nearby_cavity_echo | Mangime vegetale |
| species_ferriccio | Ferriccio | Ferrum | ground | Habitat piccolo | ability_ore_direction | Mangime vegetale |
| species_carbonello | Carbonello | Ferrum | ground | Habitat piccolo | ability_air_quality_warning | Biomassa vegetale |
| species_argillotto | Argillotto | Ferrum | ground | Habitat piccolo | ability_seal_small_leak | Mangime vegetale |
| species_brinotto | Brinotto | Brina | cold | Habitat climatico | ability_warm_bubble | Mangime vegetale |
| species_cobalina | Cobalina | Brina | cold | Habitat climatico | ability_battery_health_warning | Mangime vegetale |
| species_nevaglio | Nevaglio | Brina | cold | Habitat climatico | ability_safe_ice_route | Biomassa vegetale |
| species_algolino | Algolino | Pelagia | aquatic | Habitat acquatico | ability_algae_growth_bonus | Alghe |
| species_calciopode | Calciopode | Pelagia | aquatic | Habitat acquatico | ability_water_filter_bonus | Mangime vegetale |
| species_salifin | Salifin | Pelagia | aquatic | Habitat acquatico | ability_pressure_pocket_warning | Alghe |
| species_sporello | Sporello | Viridia | spore | Habitat climatico | ability_spore_warning | Biomassa vegetale |
| species_resinella | Resinella | Viridia | spore | Habitat climatico | ability_sealant_efficiency | Mangime vegetale |
| species_micorino | Micorino | Viridia | spore | Habitat climatico | ability_plant_growth_bonus | Biomassa vegetale |
| species_scintillo | Scintillo | Fulmen | electric | Habitat climatico | ability_ground_small_discharge | Mangime vegetale |
| species_grafotto | Grafotto | Fulmen | electric | Habitat climatico | ability_network_diagnostic | Biomassa vegetale |
| species_voltala | Voltala | Fulmen | flying | Voliera pressurizzata | ability_storm_forecast | Mangime vegetale |
| species_lavillo | Lavillo | Vulcania | hot | Habitat climatico | ability_heat_route_warning | Mangime vegetale |
| species_titanello | Titanello | Vulcania | hot | Habitat climatico | ability_reinforcement_health_warning | Mangime vegetale |
| species_sulfina | Sulfina | Vulcania | hot | Habitat climatico | ability_gas_direction_warning | Biomassa vegetale |
| species_sabbuffo | Sabbuffo | Duna | arid | Habitat climatico | ability_sandstorm_forecast | Mangime vegetale |
| species_dorimio | Dorimio | Duna | arid | Habitat climatico | ability_precision_ore_marking | Mangime vegetale |
| species_fosfolino | Fosfolino | Duna | arid | Habitat climatico | ability_soil_fertility_bonus | Biomassa vegetale |
| species_prismella | Prismella | Prismara | resonant | Santuario multispecie | ability_hidden_fracture_marking | Mangime vegetale |
| species_borotto | Borotto | Prismara | resonant | Santuario multispecie | ability_resonance_dampening | Mangime vegetale |
| species_geodino | Geodino | Prismara | resonant | Santuario multispecie | ability_crystal_room_acoustic_hint | Mangime vegetale |
| species_nembolo | Nembolo | Nimbo | flying | Voliera pressurizzata | ability_wind_window_warning | Biomassa vegetale |
| species_eliopuff | Eliopuff | Nimbo | flying | Voliera pressurizzata | ability_local_buoyancy_hint | Mangime vegetale |
| species_xenella | Xenella | Nimbo | flying | Voliera pressurizzata | ability_pressure_leak_warning | Mangime vegetale |
| species_iridonte | Iridonte | Nox | nocturnal | Santuario multispecie | ability_radiation_safe_route | Mangime vegetale |
| species_ombrolino | Ombrolino | Nox | nocturnal | Santuario multispecie | ability_low_light_vision | Biomassa vegetale |
| species_mnemonide | Mnemonide | Nox | nocturnal | Santuario multispecie | ability_map_landmark_memory | Mangime vegetale |
| species_accordino | Accordino | Concordia | concord | Santuario multispecie | ability_habitat_compatibility_bonus | Mangime vegetale |
| species_reticolino | Reticolino | Concordia | concord | Santuario multispecie | ability_network_efficiency_hint | Biomassa vegetale |
| species_astralume | Astralume | Concordia | concord | Santuario multispecie | ability_survey_landmark_glow | Mangime vegetale |

## Direzione visiva

Reference: `refs/Space_Digger.png`. Tavola preferita: [36 creature aliene 3D](../../assets/design/concepts/creatures-36-alien.png). Ordine per righe uguale al catalogo: tre specie per pianeta. La tavola guida modelli e animazioni futuri; le icone SVG hanno lo stesso ID del catalogo.
