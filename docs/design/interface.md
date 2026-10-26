# Interfaccia e stati

Catalogo generato da [gui.json](../../design/v1/gui.json). Modificare il JSON e rieseguire `node tools/design/build.mjs`. Numeri di bilanciamento iniziali, da provare nel gioco.

| ID | Schermata | Pannelli | Azione primaria | Pausa |
| --- | --- | --- | --- | --- |
| ui_hud | Esplorazione | minimal_stats, tools, goal, context_action | context_action | false |
| ui_inventory | Inventario | backpack, robbie, selected_local_station | transfer_selected | true |
| ui_build | Cubi e costruzione | stage_filtered_catalog, recipe_and_folded_cube, world_footprint_preview | create_physical_cube_at_station | menu_only |
| ui_station | Postazione | station_identity_level_power_cache, five_actions | selected_action | true |
| ui_research | Ricerca | current_tier, next_two_unlocks, materials, lumen_reserve | research | true |
| ui_upgrades | Potenziamenti | player_ship_robbie_station_tabs, current_next_comparison, physical_cost, wallet_cost | upgrade | true |
| ui_navigation | Atlante stellare | 12_planets, known_resources_and_hazards, pinned_need, route_check | prepare_departure | true |
| ui_cave_map | Mappa della caverna | visited_geometry, layer_toggles, route_and_module_reservations | place_marker | true |
| ui_creatures | Creature e habitat | species_codex, habitats_and_welfare, three_companion_slots | care_or_assign | true |
| ui_maintenance | Cura e manutenzione | character_conditions, ship_subsystems, robbie_state | repair_selected | true |
| ui_robbie_routes | Trasporti Robbie | known_docks, route_preview, cargo_reservation, battery_and_signal | start_single_job | true |

## Errori utilizzabili dal codice

| Codice | Messaggio |
| --- | --- |
| E_SPACE_SOLID | Scava ancora {cells} celle nello spazio del modulo. |
| E_SUPPORT | Manca il sostegno sotto {cells} celle. |
| E_HAZARD | Bonifica {hazard} prima del montaggio. |
| E_LOCAL_STOCK | Qui mancano {quantity} {item}. {ship_quantity} sono nella stiva della nave. |
| E_OUTPUT_FULL | Libera {units} unità per il cubo prodotto. |
| E_NO_ROUTE | Il tratto {from} → {to} non è esplorato o percorribile. |
| E_SIGNAL | Robbie non è connesso: posa un ripetitore o torna nel raggio. |
| E_RETURN_RESERVE | La rotta richiede {required} carburante inclusa la riserva. |
| E_CREATURE_HOME | Prepara un habitat {habitat} prima del trasporto. |
| E_POWER | Servono {kw} kW disponibili sulla rete locale. |
| E_OCCUPIED | Libera lo spazio di montaggio: {actor} è nella zona. |
| E_RESEARCH | Completa {research} per sbloccare questo progetto. |

## Prototipo interattivo

Aprire [l’anteprima](../../design/preview/index.html) per consultare cataloghi, ingredienti, dipendenze e i flussi di costruzione, navigazione e cura. Il prototipo usa i dati JSON incorporati dal generatore; non modifica salvataggi o runtime.
