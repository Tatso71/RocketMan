# Ricerca e progressione

Catalogo generato da [research.json](../../design/v1/research.json). Modificare il JSON e rieseguire `node tools/design/build.mjs`. Numeri di bilanciamento iniziali, da provare nel gioco.

| ID | Ricerca | Prerequisiti | Visite | Rilievi completi | Materiali | Cristalli |
| --- | --- | --- | --- | --- | --- | --- |
| tech_start | Dotazione iniziale |  |  |  | — | — |
| tech_field_science | Ricerca sul campo | Dotazione iniziale |  |  | — | — |
| tech_metallurgy | Metallurgia | Ricerca sul campo | Ferrum |  | 4 Ferro + 2 Carbone | 15 Cristalli Lumen |
| tech_sealing | Caverne attrezzate | Metallurgia | Ferrum |  | 2 Piastra di ferro + 1 Vetro | 15 Cristalli Lumen |
| tech_cold | Protezione termica | Caverne attrezzate | Ferrum |  | 2 Isolante + 2 Filo di rame | 20 Cristalli Lumen |
| tech_hydraulics | Idraulica | Caverne attrezzate | Ferrum |  | 2 Acciaio + 2 Filo di rame | 20 Cristalli Lumen |
| tech_bond | Legame con le creature | Idraulica | Ocra |  | 2 Mangime vegetale + 1 Vetro | 15 Cristalli Lumen |
| tech_biology | Biotecnologia | Idraulica | Pelagia |  | 2 Alghe + 2 Sale | 25 Cristalli Lumen |
| tech_electrics | Reti ad alta densità | Protezione termica | Brina |  | 2 Litio + 1 Cobalto | 25 Cristalli Lumen |
| tech_logistics | Trasporto assistito | Protezione termica, Idraulica | Brina |  | 1 Cella energetica + 2 Circuito | 20 Cristalli Lumen |
| tech_ecology | Habitat specialistici | Biotecnologia, Legame con le creature | Viridia |  | 2 Biogel + 1 Polimero vegetale | 25 Cristalli Lumen |
| tech_heat | Tecnologia termica | Biotecnologia, Reti ad alta densità | Viridia, Fulmen |  | 2 Ceramica + 2 Resina | 30 Cristalli Lumen |
| tech_desert | Sistemi aridi | Biotecnologia | Viridia |  | 2 Polimero vegetale + 2 Acqua | 25 Cristalli Lumen |
| tech_resonance | Risonanza e ottiche | Tecnologia termica, Sistemi aridi | Vulcania, Duna |  | 2 Nichel + 1 Oro | 40 Cristalli Lumen |
| tech_sky | Esplorazione atmosferica | Tecnologia termica, Reti ad alta densità | Vulcania, Fulmen |  | 2 Lega di titanio + 1 Bobina magnetica | 40 Cristalli Lumen |
| tech_symbiosis | Simbiosi multispecie | Habitat specialistici, Risonanza e ottiche | Prismara |  | 2 Nutrienti + 1 Quarzo prismatico | 40 Cristalli Lumen |
| tech_void | Esplorazione profonda | Risonanza e ottiche, Esplorazione atmosferica | Prismara, Nimbo |  | 1 Lente prismatica + 1 Fluido criogenico | 50 Cristalli Lumen |
| tech_concord | Atlante concorde | Esplorazione profonda, Simbiosi multispecie |  | Ocra, Ferrum, Brina, Pelagia, Viridia, Fulmen, Vulcania, Duna, Prismara, Nimbo, Nox | 1 Matrice cartografica + 1 Lente notturna | 60 Cristalli Lumen |

## Prime azioni

| Passo | Minuto obiettivo | Azione | Verifica |
| --- | --- | --- | --- |
| 1 | 2 | Scendi nell’officina e apri il portello | hatch_open |
| 2 | 5 | Scava due celle e posa la prima scala | first_ladder_placed |
| 3 | 10 | Prepara e trasporta il cubo laboratorio | lab_cube_carried |
| 4 | 18 | Libera 4 per 3 metri e dispiega il laboratorio | first_lab |
| 5 | 23 | Fabbrica e posa una luce | first_light |
| 6 | 30 | Scansiona un punto di interesse e prepara Ferrum | first_destination_plan |

## Fasi

| Fase | Pianeti | Sistemi introdotti | Obiettivo di cura |
| --- | --- | --- | --- |
| 0 | Ocra | dig, cube, light, local_inventory | free_ship_healing_no_oxygen_loss_training_pocket |
| 1 | Ferrum | fabricator, alloys, support, sealing | ship_hull_and_suit_repair_introduced_separately |
| 2 | Brina, Pelagia | temperature, pump, battery, first_companion | oxygen_return_estimate_and_recoverable_cache |
| 3 | Viridia, Fulmen | filters, bioprocessing, power_network, robbie_routes | creature_habitat_automation_and_robbie_service |
| 4 | Vulcania, Duna | heat, advanced_alloys, ship_external_pods | preventive_ship_maintenance_and_rescue_beacons |
| 5 | Prismara, Nimbo | resonance, wind, specialist_habitats, third_companion | multiple_hazards_with_known_counters |
| 6 | Nox | deep_caves, radiation, atlas | long_return_routes_and_forward_safe_rooms |
| 7 | Concordia | combined_networks, multispecies_sanctuary, completion_projects | apply_existing_systems_no_new_survival_meter |
