# Cubi installabili e funzioni

Catalogo generato da [modules.json](../../design/v1/modules.json). Modificare il JSON e rieseguire `node tools/design/build.mjs`. Numeri di bilanciamento iniziali, da provare nel gioco.

| ID | Modulo | Fase | Aperto X per Y m | Carico chiuso | kW | Deposito | Aggancio |
| --- | --- | --- | --- | --- | --- | --- | --- |
| mod_workshop | Officina di bordo | 0 | 4 × 3 | 0 | 0 | 0 | ship_internal |
| mod_ladder | Scala di emergenza | 0 | 1 × 1 | 1 | 0 | 0 | floor_or_vertical_chain |
| mod_lab | Laboratorio da campo | 0 | 4 × 3 | 4 | 0.2 | 32 | floor |
| mod_light | Luce da galleria | 0 | 1 × 1 | 1 | 0.02 | 0 | floor |
| mod_crate | Deposito locale | 1 | 2 × 2 | 2 | 0 | 48 | floor |
| mod_fabricator | Fabbricatore | 1 | 3 × 3 | 4 | 0.6 | 16 | floor |
| mod_support | Arco di sostegno | 1 | 2 × 2 | 2 | 0 | 0 | floor |
| mod_door | Porta stagna | 1 | 1 × 2 | 2 | 0.02 | 0 | floor |
| mod_airlock | Camera di compensazione | 1 | 3 × 3 | 4 | 0.08 | 0 | floor |
| mod_life_support | Supporto vitale | 1 | 2 × 3 | 3 | 0.3 | 4 | floor |
| mod_solar | Pannello solare | 1 | 3 × 2 | 3 | 0 | 0 | surface |
| mod_battery_bank | Accumulatore | 2 | 2 × 2 | 3 | 0 | 0 | floor |
| mod_heater | Termoregolatore | 2 | 2 × 2 | 3 | 0.4 | 0 | floor |
| mod_pump | Pompa idrica | 2 | 2 × 2 | 3 | 0.2 | 0 | floor |
| mod_tank | Serbatoio | 2 | 2 × 3 | 3 | 0 | 0 | floor |
| mod_relay | Ripetitore | 2 | 1 × 2 | 2 | 0.04 | 0 | floor |
| mod_greenhouse | Serra | 2 | 4 × 3 | 5 | 0.15 | 16 | floor |
| mod_habitat | Habitat piccolo | 2 | 4 × 3 | 4 | 0.15 | 12 | floor |
| mod_infirmary | Infermeria | 2 | 3 × 3 | 4 | 0.2 | 8 | floor |
| mod_bioprocessor | Bioprocessore | 3 | 3 × 3 | 4 | 0.4 | 16 | floor |
| mod_gas_filter | Filtro gas avanzato | 3 | 2 × 2 | 3 | 0.25 | 4 | floor |
| mod_route_dock | Stazione Robbie | 3 | 2 × 2 | 3 | 0.08 | 24 | floor |
| mod_fuel_plant | Impianto propellente | 2 | 3 × 3 | 4 | 0.4 | 16 | floor |
| mod_magnetic_shield | Schermo elettromagnetico | 3 | 2 × 3 | 4 | 0.5 | 0 | floor |
| mod_geothermal | Generatore geotermico | 4 | 3 × 3 | 5 | 0 | 0 | geothermal_vent |
| mod_habitat_aquatic | Habitat acquatico | 3 | 4 × 3 | 5 | 0.25 | 16 | floor |
| mod_habitat_climate | Habitat climatico | 3 | 5 × 3 | 6 | 0.4 | 20 | floor |
| mod_photonics | Banco fotonico | 4 | 3 × 3 | 5 | 0.6 | 16 | floor |
| mod_observatory | Osservatorio | 5 | 4 × 4 | 6 | 0.5 | 8 | ceiling_clear_sky |
| mod_habitat_aviary | Voliera pressurizzata | 5 | 5 × 4 | 6 | 0.4 | 20 | floor |
| mod_sanctuary | Santuario multispecie | 5 | 6 × 4 | 8 | 0.6 | 32 | floor |
| mod_beacon | Faro di soccorso | 4 | 2 × 3 | 4 | 0.1 | 4 | floor |
| mod_drain | Drenaggio passivo | 2 | 1 × 1 | 1 | 0 | 0 | floor |
| mod_pipe | Condotta | 1 | 1 × 1 | 1 | 0 | 0 | wall_or_floor |
| mod_cable | Cavo di rete | 1 | 1 × 1 | 1 | 0 | 0 | wall_or_floor |
| mod_concord_archive | Archivio concorde | 7 | 5 × 4 | 8 | 1 | 32 | floor |
| mod_ship_cargo_pod | Stiva esterna | 2 | 3 × 3 | 6 | 0.05 | 80 | ship_side_socket |
| mod_ship_engine_pod | Motore ausiliario | 4 | 2 × 3 | 6 | 0.2 | 0 | ship_engine_socket |
| mod_ship_radar_pod | Radar esterno | 5 | 3 × 2 | 5 | 0.25 | 0 | ship_radar_socket |
| mod_ship_battery_pod | Batteria esterna | 3 | 2 × 2 | 5 | 0 | 0 | ship_side_socket |

## Officina di bordo

- ID: `mod_workshop`. Ricerca: Dotazione iniziale.
- Funzioni: assembly, repair, upgrade, craft.
- Costruisce: Filo di rame; Vetro; Filtro a carbone; Mangime vegetale; Scala di emergenza; Laboratorio da campo; Deposito locale; Fabbricatore; Propellente elettrolitico; Toppa per tuta; Sciogli ghiaccio; Luce da galleria.
- Cura e servizi: Rifornisci 20 carburante; Rifornisci 50 carburante; Ripara scafo; Cura e ripristino a bordo; Cura Robbie a bordo; Servizio propulsori.
- Upgrade: nessun livello locale; ingombro invariato.

## Scala di emergenza

- ID: `mod_ladder`. Ricerca: Dotazione iniziale.
- Funzioni: traverse_vertical.
- Costruisce: nessuna ricetta; modulo di servizio.
- Cura e servizi: —.
- Upgrade: nessun livello locale; ingombro invariato.

## Laboratorio da campo

- ID: `mod_lab`. Ricerca: Dotazione iniziale.
- Funzioni: research, scan_analysis, cache, craft_light, repair_suit.
- Costruisce: Luce da galleria.
- Cura e servizi: Ripristino tuta sul campo.
- Upgrade: upg_module_lab; ingombro invariato.

## Luce da galleria

- ID: `mod_light`. Ricerca: Ricerca sul campo.
- Funzioni: illuminate.
- Costruisce: nessuna ricetta; modulo di servizio.
- Cura e servizi: —.
- Upgrade: upg_module_light; ingombro invariato.

## Deposito locale

- ID: `mod_crate`. Ricerca: Ricerca sul campo.
- Funzioni: cache, route_endpoint.
- Costruisce: nessuna ricetta; modulo di servizio.
- Cura e servizi: —.
- Upgrade: upg_module_crate; ingombro invariato.

## Fabbricatore

- ID: `mod_fabricator`. Ricerca: Ricerca sul campo.
- Funzioni: smelt, process, assemble_cubes.
- Costruisce: Piastra di ferro; Acciaio; Ceramica; Circuito; Isolante; Cella energetica; Refrigerante salino; Sigillante; Telaio pressurizzato; Bobina magnetica; Cella ad alta densità; Scudo termico; Lega di titanio; Circuito di precisione; Ceramica tecnica; Telaio all'iridio; Arco di sostegno; Porta stagna; Camera di compensazione; Supporto vitale; Pannello solare; Accumulatore; Termoregolatore; Pompa idrica; Serbatoio; Ripetitore; Serra; Habitat piccolo; Infermeria; Bioprocessore; Filtro gas avanzato; Stazione Robbie; Impianto propellente; Schermo elettromagnetico; Generatore geotermico; Habitat acquatico; Habitat climatico; Banco fotonico; Osservatorio; Voliera pressurizzata; Santuario multispecie; Faro di soccorso; Drenaggio passivo; Condotta; Cavo di rete; Archivio concorde; Stiva esterna; Motore ausiliario; Radar esterno; Batteria esterna; Bracciale pressorio; Culla di stasi.
- Cura e servizi: —.
- Upgrade: upg_module_fabricator; ingombro invariato.

## Arco di sostegno

- ID: `mod_support`. Ricerca: Caverne attrezzate.
- Funzioni: support_8m.
- Costruisce: nessuna ricetta; modulo di servizio.
- Cura e servizi: —.
- Upgrade: nessun livello locale; ingombro invariato.

## Porta stagna

- ID: `mod_door`. Ricerca: Caverne attrezzate.
- Funzioni: seal, manual_override.
- Costruisce: nessuna ricetta; modulo di servizio.
- Cura e servizi: —.
- Upgrade: nessun livello locale; ingombro invariato.

## Camera di compensazione

- ID: `mod_airlock`. Ricerca: Caverne attrezzate.
- Funzioni: safe_transition, seal.
- Costruisce: nessuna ricetta; modulo di servizio.
- Cura e servizi: —.
- Upgrade: nessun livello locale; ingombro invariato.

## Supporto vitale

- ID: `mod_life_support`. Ricerca: Caverne attrezzate.
- Funzioni: oxygen_refill, air_filter, room_condition.
- Costruisce: nessuna ricetta; modulo di servizio.
- Cura e servizi: —.
- Upgrade: upg_module_life_support; ingombro invariato.

## Pannello solare

- ID: `mod_solar`. Ricerca: Metallurgia.
- Funzioni: generate_solar_1kw.
- Costruisce: nessuna ricetta; modulo di servizio.
- Cura e servizi: —.
- Upgrade: upg_module_solar; ingombro invariato.

## Accumulatore

- ID: `mod_battery_bank`. Ricerca: Protezione termica.
- Funzioni: store_40kwh.
- Costruisce: nessuna ricetta; modulo di servizio.
- Cura e servizi: —.
- Upgrade: upg_module_battery_bank; ingombro invariato.

## Termoregolatore

- ID: `mod_heater`. Ricerca: Protezione termica.
- Funzioni: warm_room, cool_room.
- Costruisce: nessuna ricetta; modulo di servizio.
- Cura e servizi: —.
- Upgrade: nessun livello locale; ingombro invariato.

## Pompa idrica

- ID: `mod_pump`. Ricerca: Idraulica.
- Funzioni: transfer_water_2litres_second.
- Costruisce: nessuna ricetta; modulo di servizio.
- Cura e servizi: —.
- Upgrade: upg_module_pump; ingombro invariato.

## Serbatoio

- ID: `mod_tank`. Ricerca: Idraulica.
- Funzioni: store_200litres.
- Costruisce: nessuna ricetta; modulo di servizio.
- Cura e servizi: —.
- Upgrade: nessun livello locale; ingombro invariato.

## Ripetitore

- ID: `mod_relay`. Ricerca: Protezione termica.
- Funzioni: extend_radio_15m_clear_path.
- Costruisce: nessuna ricetta; modulo di servizio.
- Cura e servizi: —.
- Upgrade: upg_module_relay; ingombro invariato.

## Serra

- ID: `mod_greenhouse`. Ricerca: Idraulica.
- Funzioni: grow_biomass, grow_algae, feed.
- Costruisce: Coltiva biomassa; Coltiva alghe; Coltiva resina; Coltiva spore.
- Cura e servizi: —.
- Upgrade: upg_module_greenhouse; ingombro invariato.

## Habitat piccolo

- ID: `mod_habitat`. Ricerca: Legame con le creature.
- Funzioni: house_2_small_species, care, passive_outputs.
- Costruisce: nessuna ricetta; modulo di servizio.
- Cura e servizi: —.
- Upgrade: upg_module_habitat; ingombro invariato.

## Infermeria

- ID: `mod_infirmary`. Ricerca: Protezione termica.
- Funzioni: heal, repair_suit, remove_contamination.
- Costruisce: nessuna ricetta; modulo di servizio.
- Cura e servizi: Trattamento completo.
- Upgrade: upg_module_infirmary; ingombro invariato.

## Bioprocessore

- ID: `mod_bioprocessor`. Ricerca: Biotecnologia.
- Funzioni: bio_refine, medicine, membranes.
- Costruisce: Polimero vegetale; Biogel; Membrana selettiva; Gel curativo; Lubrificante; Nutrienti; Aerogel; Coltura enzimatica.
- Cura e servizi: —.
- Upgrade: nessun livello locale; ingombro invariato.

## Filtro gas avanzato

- ID: `mod_gas_filter`. Ricerca: Biotecnologia.
- Funzioni: filter_spores_and_toxic_gas.
- Costruisce: nessuna ricetta; modulo di servizio.
- Cura e servizi: —.
- Upgrade: upg_module_gas_filter; ingombro invariato.

## Stazione Robbie

- ID: `mod_route_dock`. Ricerca: Trasporto assistito.
- Funzioni: route_endpoint, charge_robbie, repair_robbie.
- Costruisce: nessuna ricetta; modulo di servizio.
- Cura e servizi: Manutenzione Robbie.
- Upgrade: upg_module_route_dock; ingombro invariato.

## Impianto propellente

- ID: `mod_fuel_plant`. Ricerca: Idraulica.
- Funzioni: water_electrolysis, fuel_conversion.
- Costruisce: Propellente a elio.
- Cura e servizi: —.
- Upgrade: nessun livello locale; ingombro invariato.

## Schermo elettromagnetico

- ID: `mod_magnetic_shield`. Ricerca: Reti ad alta densità.
- Funzioni: ground_storms, protect_local_network.
- Costruisce: nessuna ricetta; modulo di servizio.
- Cura e servizi: —.
- Upgrade: nessun livello locale; ingombro invariato.

## Generatore geotermico

- ID: `mod_geothermal`. Ricerca: Tecnologia termica.
- Funzioni: generate_4kw.
- Costruisce: nessuna ricetta; modulo di servizio.
- Cura e servizi: —.
- Upgrade: nessun livello locale; ingombro invariato.

## Habitat acquatico

- ID: `mod_habitat_aquatic`. Ricerca: Habitat specialistici.
- Funzioni: house_2_aquatic_species, water_loop.
- Costruisce: nessuna ricetta; modulo di servizio.
- Cura e servizi: —.
- Upgrade: upg_module_habitat_aquatic; ingombro invariato.

## Habitat climatico

- ID: `mod_habitat_climate`. Ricerca: Habitat specialistici.
- Funzioni: house_2_cold_hot_or_spore_species.
- Costruisce: nessuna ricetta; modulo di servizio.
- Cura e servizi: —.
- Upgrade: upg_module_habitat_climate; ingombro invariato.

## Banco fotonico

- ID: `mod_photonics`. Ricerca: Risonanza e ottiche.
- Funzioni: optics, resonant_components.
- Costruisce: Lente prismatica; Superconduttore; Nucleo risonante tecnico; Fluido criogenico; Lente notturna; Matrice cartografica; Matrice concorde.
- Cura e servizi: —.
- Upgrade: upg_module_photonics; ingombro invariato.

## Osservatorio

- ID: `mod_observatory`. Ricerca: Risonanza e ottiche.
- Funzioni: deep_scan, chart_routes.
- Costruisce: nessuna ricetta; modulo di servizio.
- Cura e servizi: —.
- Upgrade: nessun livello locale; ingombro invariato.

## Voliera pressurizzata

- ID: `mod_habitat_aviary`. Ricerca: Esplorazione atmosferica.
- Funzioni: house_2_flying_species.
- Costruisce: nessuna ricetta; modulo di servizio.
- Cura e servizi: —.
- Upgrade: upg_module_habitat_aviary; ingombro invariato.

## Santuario multispecie

- ID: `mod_sanctuary`. Ricerca: Simbiosi multispecie.
- Funzioni: house_4_compatible_species, study_synergy.
- Costruisce: nessuna ricetta; modulo di servizio.
- Cura e servizi: —.
- Upgrade: upg_module_sanctuary; ingombro invariato.

## Faro di soccorso

- ID: `mod_beacon`. Ricerca: Tecnologia termica.
- Funzioni: safe_rescue_anchor, map_route.
- Costruisce: nessuna ricetta; modulo di servizio.
- Cura e servizi: —.
- Upgrade: nessun livello locale; ingombro invariato.

## Drenaggio passivo

- ID: `mod_drain`. Ricerca: Idraulica.
- Funzioni: direct_finite_water_to_lower_tank.
- Costruisce: nessuna ricetta; modulo di servizio.
- Cura e servizi: —.
- Upgrade: nessun livello locale; ingombro invariato.

## Condotta

- ID: `mod_pipe`. Ricerca: Caverne attrezzate.
- Funzioni: connect_fluid_or_air_selected_mode.
- Costruisce: nessuna ricetta; modulo di servizio.
- Cura e servizi: —.
- Upgrade: nessun livello locale; ingombro invariato.

## Cavo di rete

- ID: `mod_cable`. Ricerca: Caverne attrezzate.
- Funzioni: connect_power_and_data.
- Costruisce: nessuna ricetta; modulo di servizio.
- Cura e servizi: —.
- Upgrade: nessun livello locale; ingombro invariato.

## Archivio concorde

- ID: `mod_concord_archive`. Ricerca: Atlante concorde.
- Funzioni: complete_atlas, endgame_projects.
- Costruisce: nessuna ricetta; modulo di servizio.
- Cura e servizi: —.
- Upgrade: nessun livello locale; ingombro invariato.

## Stiva esterna

- ID: `mod_ship_cargo_pod`. Ricerca: Protezione termica.
- Funzioni: add_80_ship_stock, visible_pod.
- Costruisce: nessuna ricetta; modulo di servizio.
- Cura e servizi: —.
- Upgrade: nessun livello locale; ingombro invariato.

## Motore ausiliario

- ID: `mod_ship_engine_pod`. Ricerca: Tecnologia termica.
- Funzioni: reduce_route_fuel_12percent, visible_engine.
- Costruisce: nessuna ricetta; modulo di servizio.
- Cura e servizi: —.
- Upgrade: nessun livello locale; ingombro invariato.

## Radar esterno

- ID: `mod_ship_radar_pod`. Ricerca: Risonanza e ottiche.
- Funzioni: reveal_optional_landing_sites, visible_radar.
- Costruisce: nessuna ricetta; modulo di servizio.
- Cura e servizi: —.
- Upgrade: nessun livello locale; ingombro invariato.

## Batteria esterna

- ID: `mod_ship_battery_pod`. Ricerca: Reti ad alta densità.
- Funzioni: add_80kwh, visible_battery.
- Costruisce: nessuna ricetta; modulo di servizio.
- Cura e servizi: —.
- Upgrade: nessun livello locale; ingombro invariato.
