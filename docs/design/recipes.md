# Ricette e postazioni

Catalogo generato da [recipes.json](../../design/v1/recipes.json). Modificare il JSON e rieseguire `node tools/design/build.mjs`. Numeri di bilanciamento iniziali, da provare nel gioco.

Le scale sono costruzione manuale immediata sul posto: 2 Terriccio, zero secondi e zero energia. Nessun cubo, officina, laboratorio, Robbie o segnale; l'output e direttamente la scala attiva nel mondo, non un oggetto nello zaino. L'ID storico recipe_cube_ladder resta stabile, ma non indica un cubo.

| ID | Postazione | Ricerca | Ingredienti | Risultato | Secondi | kWh |
| --- | --- | --- | --- | --- | --- | --- |
| recipe_wire | Officina di bordo | Dotazione iniziale | 2 Rame | 2 Filo di rame | 3 | 0.006 |
| recipe_glass | Officina di bordo | Ricerca sul campo | 2 Silice | 1 Vetro | 4 | 0.008 |
| recipe_plate | Fabbricatore | Metallurgia | 2 Ferro + 1 Carbone | 2 Piastra di ferro | 5 | 0.01 |
| recipe_steel | Fabbricatore | Metallurgia | 2 Ferro + 1 Carbone | 2 Acciaio | 6 | 0.012 |
| recipe_ceramic | Fabbricatore | Metallurgia | 2 Argilla + 1 Silice | 2 Ceramica | 5 | 0.01 |
| recipe_filter | Officina di bordo | Caverne attrezzate | 1 Carbone + 1 Biomassa vegetale | 2 Filtro a carbone | 3 | 0.006 |
| recipe_circuit | Fabbricatore | Metallurgia | 2 Filo di rame + 1 Vetro | 1 Circuito | 5 | 0.01 |
| recipe_insulation | Fabbricatore | Caverne attrezzate | 1 Ceramica + 1 Biomassa vegetale | 2 Isolante | 4 | 0.008 |
| recipe_battery | Fabbricatore | Protezione termica | 1 Litio + 1 Cobalto + 1 Carbone | 1 Cella energetica | 6 | 0.012 |
| recipe_coolant | Fabbricatore | Idraulica | 2 Acqua + 1 Sale | 2 Refrigerante salino | 4 | 0.008 |
| recipe_feed | Officina di bordo | Dotazione iniziale | 1 Biomassa vegetale + 1 Acqua | 2 Mangime vegetale | 2 | 0.004 |
| recipe_polymer | Bioprocessore | Biotecnologia | 2 Resina + 1 Alghe | 2 Polimero vegetale | 5 | 0.01 |
| recipe_sealant | Fabbricatore | Biotecnologia | 1 Polimero vegetale + 1 Silice | 2 Sigillante | 4 | 0.008 |
| recipe_bio_gel | Bioprocessore | Biotecnologia | 1 Alghe + 1 Resina | 2 Biogel | 5 | 0.01 |
| recipe_membrane | Bioprocessore | Biotecnologia | 1 Biogel + 1 Enzimi | 2 Membrana selettiva | 6 | 0.012 |
| recipe_medgel | Bioprocessore | Biotecnologia | 1 Biogel + 1 Acqua + 1 Enzimi | 2 Gel curativo | 6 | 0.012 |
| recipe_pressure_frame | Fabbricatore | Biotecnologia | 2 Acciaio + 1 Polimero vegetale | 1 Telaio pressurizzato | 8 | 0.016 |
| recipe_magnetic_coil | Fabbricatore | Reti ad alta densità | 2 Filo di rame + 1 Magnetite | 1 Bobina magnetica | 6 | 0.012 |
| recipe_advanced_battery | Fabbricatore | Reti ad alta densità | 1 Cella energetica + 1 Grafite + 1 Vanadio | 1 Cella ad alta densità | 8 | 0.016 |
| recipe_heat_shield | Fabbricatore | Tecnologia termica | 2 Ceramica + 1 Carbone + 1 Filo di rame | 1 Scudo termico | 7 | 0.014 |
| recipe_titanium_alloy | Fabbricatore | Tecnologia termica | 2 Titanio + 1 Nichel | 2 Lega di titanio | 10 | 0.02 |
| recipe_lubricant | Bioprocessore | Tecnologia termica | 1 Resina + 1 Zolfo | 2 Lubrificante | 4 | 0.008 |
| recipe_gold_circuit | Fabbricatore | Sistemi aridi | 1 Circuito + 1 Oro | 1 Circuito di precisione | 8 | 0.016 |
| recipe_nutrient | Bioprocessore | Sistemi aridi | 1 Fosfati + 1 Alghe + 1 Acqua | 3 Nutrienti | 5 | 0.01 |
| recipe_advanced_ceramic | Fabbricatore | Sistemi aridi | 2 Allumina + 1 Ceramica + 1 Calcite | 2 Ceramica tecnica | 8 | 0.016 |
| recipe_prism_lens | Banco fotonico | Risonanza e ottiche | 2 Quarzo prismatico + 1 Vetro | 1 Lente prismatica | 10 | 0.02 |
| recipe_superconductor | Banco fotonico | Risonanza e ottiche | 1 Vanadio + 1 Borati + 1 Refrigerante salino | 1 Superconduttore | 12 | 0.024 |
| recipe_resonant_core | Banco fotonico | Risonanza e ottiche | 1 Seme geodico + 1 Circuito di precisione | 1 Nucleo risonante tecnico | 12 | 0.024 |
| recipe_aerogel | Bioprocessore | Esplorazione atmosferica | 2 Aerospore + 1 Silice | 2 Aerogel | 10 | 0.02 |
| recipe_cryo_fluid | Banco fotonico | Esplorazione atmosferica | 1 Xeno + 1 Refrigerante salino | 2 Fluido criogenico | 10 | 0.02 |
| recipe_helium_fuel | Impianto propellente | Esplorazione atmosferica | 1 Elio 3 + 1 Acqua | 2 Propellente a elio | 8 | 0.016 |
| recipe_iridium_frame | Fabbricatore | Esplorazione profonda | 2 Iridio + 1 Lega di titanio | 1 Telaio all'iridio | 15 | 0.03 |
| recipe_dark_lens | Banco fotonico | Esplorazione profonda | 1 Silicato oscuro + 1 Lente prismatica | 1 Lente notturna | 15 | 0.03 |
| recipe_atlas_chip | Banco fotonico | Esplorazione profonda | 1 Perla mnemonica + 1 Circuito di precisione | 1 Matrice cartografica | 15 | 0.03 |
| recipe_concord_matrix | Banco fotonico | Atlante concorde | 1 Reticolo concorde + 1 Matrice cartografica + 1 Superconduttore | 1 Matrice concorde | 20 | 0.04 |
| recipe_cube_ladder | Sul campo | Dotazione iniziale | 2 Terriccio | 1 Scala di emergenza | 0 | 0 |
| recipe_cube_lab | Officina di bordo | Dotazione iniziale | 6 Pietra + 4 Rame | 1 Laboratorio da campo | 5 | 0.01 |
| recipe_cube_light | Laboratorio da campo | Ricerca sul campo | 1 Terriccio + 1 Rame | 1 Luce da galleria | 5 | 0.01 |
| recipe_cube_crate | Officina di bordo | Ricerca sul campo | 4 Pietra + 2 Rame | 1 Deposito locale | 8 | 0.02 |
| recipe_cube_fabricator | Officina di bordo | Ricerca sul campo | 4 Pietra + 4 Rame | 1 Fabbricatore | 8 | 0.02 |
| recipe_cube_support | Fabbricatore | Caverne attrezzate | 2 Acciaio + 2 Pietra | 1 Arco di sostegno | 8 | 0.02 |
| recipe_cube_door | Fabbricatore | Caverne attrezzate | 2 Piastra di ferro + 1 Ceramica + 1 Filo di rame | 1 Porta stagna | 8 | 0.02 |
| recipe_cube_airlock | Fabbricatore | Caverne attrezzate | 3 Acciaio + 1 Vetro + 1 Filtro a carbone | 1 Camera di compensazione | 8 | 0.02 |
| recipe_cube_life_support | Fabbricatore | Caverne attrezzate | 2 Filtro a carbone + 2 Filo di rame + 2 Piastra di ferro | 1 Supporto vitale | 8 | 0.02 |
| recipe_cube_solar | Fabbricatore | Metallurgia | 2 Vetro + 3 Filo di rame + 1 Piastra di ferro | 1 Pannello solare | 8 | 0.02 |
| recipe_cube_battery_bank | Fabbricatore | Protezione termica | 2 Cella energetica + 2 Filo di rame + 1 Piastra di ferro | 1 Accumulatore | 11 | 0.03 |
| recipe_cube_heater | Fabbricatore | Protezione termica | 2 Isolante + 2 Filo di rame + 1 Piastra di ferro | 1 Termoregolatore | 11 | 0.03 |
| recipe_cube_pump | Fabbricatore | Idraulica | 2 Acciaio + 2 Filo di rame + 1 Filtro a carbone | 1 Pompa idrica | 11 | 0.03 |
| recipe_cube_tank | Fabbricatore | Idraulica | 3 Acciaio + 1 Vetro | 1 Serbatoio | 11 | 0.03 |
| recipe_cube_relay | Fabbricatore | Protezione termica | 1 Circuito + 2 Filo di rame + 1 Piastra di ferro | 1 Ripetitore | 11 | 0.03 |
| recipe_cube_greenhouse | Fabbricatore | Idraulica | 3 Vetro + 2 Acciaio + 2 Acqua | 1 Serra | 11 | 0.03 |
| recipe_cube_habitat | Fabbricatore | Legame con le creature | 2 Vetro + 2 Acciaio + 2 Mangime vegetale | 1 Habitat piccolo | 11 | 0.03 |
| recipe_cube_infirmary | Fabbricatore | Protezione termica | 2 Acciaio + 1 Vetro + 2 Filtro a carbone | 1 Infermeria | 11 | 0.03 |
| recipe_cube_bioprocessor | Fabbricatore | Biotecnologia | 2 Acciaio + 2 Vetro + 1 Filtro a carbone | 1 Bioprocessore | 14 | 0.04 |
| recipe_cube_gas_filter | Fabbricatore | Biotecnologia | 2 Membrana selettiva + 2 Filo di rame + 1 Acciaio | 1 Filtro gas avanzato | 14 | 0.04 |
| recipe_cube_route_dock | Fabbricatore | Trasporto assistito | 2 Circuito + 2 Acciaio + 1 Cella energetica | 1 Stazione Robbie | 14 | 0.04 |
| recipe_cube_fuel_plant | Fabbricatore | Idraulica | 3 Acciaio + 2 Filo di rame + 1 Filtro a carbone | 1 Impianto propellente | 11 | 0.03 |
| recipe_cube_magnetic_shield | Fabbricatore | Reti ad alta densità | 2 Bobina magnetica + 2 Acciaio + 1 Cella energetica | 1 Schermo elettromagnetico | 14 | 0.04 |
| recipe_cube_geothermal | Fabbricatore | Tecnologia termica | 2 Scudo termico + 3 Acciaio + 2 Filo di rame | 1 Generatore geotermico | 17 | 0.05 |
| recipe_cube_habitat_aquatic | Fabbricatore | Habitat specialistici | 2 Telaio pressurizzato + 3 Vetro + 1 Membrana selettiva | 1 Habitat acquatico | 14 | 0.04 |
| recipe_cube_habitat_climate | Fabbricatore | Habitat specialistici | 2 Telaio pressurizzato + 2 Isolante + 1 Cella energetica | 1 Habitat climatico | 14 | 0.04 |
| recipe_cube_photonics | Fabbricatore | Risonanza e ottiche | 2 Circuito di precisione + 2 Vetro + 1 Lega di titanio | 1 Banco fotonico | 17 | 0.05 |
| recipe_cube_observatory | Fabbricatore | Risonanza e ottiche | 1 Lente prismatica + 2 Lega di titanio + 1 Circuito di precisione | 1 Osservatorio | 20 | 0.06 |
| recipe_cube_habitat_aviary | Fabbricatore | Esplorazione atmosferica | 2 Telaio pressurizzato + 2 Aerogel + 2 Vetro | 1 Voliera pressurizzata | 20 | 0.06 |
| recipe_cube_sanctuary | Fabbricatore | Simbiosi multispecie | 3 Telaio pressurizzato + 2 Ceramica tecnica + 1 Lente prismatica | 1 Santuario multispecie | 20 | 0.06 |
| recipe_cube_beacon | Fabbricatore | Tecnologia termica | 1 Lega di titanio + 1 Cella energetica + 2 Circuito | 1 Faro di soccorso | 17 | 0.05 |
| recipe_cube_drain | Fabbricatore | Idraulica | 1 Acciaio + 1 Filtro a carbone | 1 Drenaggio passivo | 11 | 0.03 |
| recipe_cube_pipe | Fabbricatore | Caverne attrezzate | 1 Piastra di ferro | 1 Condotta | 8 | 0.02 |
| recipe_cube_cable | Fabbricatore | Caverne attrezzate | 1 Filo di rame | 1 Cavo di rete | 8 | 0.02 |
| recipe_cube_concord_archive | Fabbricatore | Atlante concorde | 2 Matrice concorde + 2 Telaio all'iridio + 2 Aerogel | 1 Archivio concorde | 26 | 0.08 |
| recipe_cube_ship_cargo_pod | Fabbricatore | Protezione termica | 4 Acciaio + 2 Filo di rame + 1 Isolante | 1 Stiva esterna | 11 | 0.03 |
| recipe_cube_ship_engine_pod | Fabbricatore | Tecnologia termica | 3 Lega di titanio + 1 Scudo termico + 1 Bobina magnetica | 1 Motore ausiliario | 17 | 0.05 |
| recipe_cube_ship_radar_pod | Fabbricatore | Risonanza e ottiche | 1 Lente prismatica + 2 Circuito di precisione + 1 Lega di titanio | 1 Radar esterno | 20 | 0.06 |
| recipe_cube_ship_battery_pod | Fabbricatore | Reti ad alta densità | 2 Cella ad alta densità + 2 Acciaio | 1 Batteria esterna | 14 | 0.04 |
| recipe_hydrogen_fuel | Officina di bordo | Dotazione iniziale | 2 Acqua | 1 Propellente elettrolitico | 30 | 4 |
| recipe_repair_patch | Officina di bordo | Ricerca sul campo | 1 Biomassa vegetale + 1 Filo di rame | 2 Toppa per tuta | 4 | 0.01 |
| recipe_pressure_cuff | Fabbricatore | Idraulica | 1 Acciaio + 1 Vetro + 1 Filo di rame | 1 Bracciale pressorio | 5 | 0.02 |
| recipe_grow_biomass | Serra | Idraulica | 1 Acqua + 1 Biomassa vegetale | 3 Biomassa vegetale | 120 | 0.06 |
| recipe_grow_algae | Serra | Idraulica | 1 Acqua + 1 Alghe | 3 Alghe | 150 | 0.075 |
| recipe_grow_resin | Serra | Biotecnologia | 1 Acqua + 1 Biomassa vegetale + 1 Resina | 2 Resina | 180 | 0.09 |
| recipe_grow_spores | Serra | Biotecnologia | 1 Acqua + 1 Biomassa vegetale + 1 Spore dormienti | 2 Spore dormienti | 180 | 0.09 |
| recipe_culture_enzymes | Bioprocessore | Biotecnologia | 1 Spore dormienti + 1 Alghe | 2 Enzimi | 150 | 0.075 |
| recipe_melt_ice | Officina di bordo | Protezione termica | 1 Ghiaccio | 1 Acqua | 10 | 0.005 |
| recipe_cube_light_ship | Officina di bordo | Ricerca sul campo | 1 Terriccio + 1 Rame | 1 Luce da galleria | 5 | 0.01 |
| recipe_stasis_carrier | Fabbricatore | Legame con le creature | 1 Vetro + 1 Acciaio | 1 Culla di stasi riutilizzabile | 8 | 0.02 |

## Servizi di cura e manutenzione

| ID | Postazione | Ingredienti | Effetti | Secondi |
| --- | --- | --- | --- | --- |
| svc_refuel_basic | Officina di bordo | 1 Propellente elettrolitico | {"ship_fuel_add":20} | 5 |
| svc_refuel_advanced | Officina di bordo | 1 Propellente a elio | {"ship_fuel_add":50} | 5 |
| svc_hull_repair | Officina di bordo | 2 Pietra + 1 Rame | {"ship_hull_add":25} | 10 |
| svc_suit_ship | Officina di bordo | — | {"player_health_set":"max","suit_integrity_set":"max","oxygen_refill":true} | 30 |
| svc_suit_field | Laboratorio da campo | 2 Terriccio + 1 Rame | {"suit_integrity_set":"max"} | 15 |
| svc_medgel | Sul campo | 1 Gel curativo | {"player_health_add":30,"cooldown_seconds":20} | 2 |
| svc_patch | Sul campo | 1 Toppa per tuta | {"suit_integrity_add":25,"remove_condition":"suit_leak"} | 5 |
| svc_clinic | Infermeria | 1 Acqua + 1 Filtro a carbone | {"player_health_set":"max","remove_conditions":["injury","contamination","thermal_strain"]} | 60 |
| svc_robbie_repair | Stazione Robbie | 1 Filo di rame + 1 Piastra di ferro | {"robbie_integrity_set":"max","robbie_battery_refill":true} | 20 |
| svc_ship_robbie | Officina di bordo | 1 Rame | {"robbie_integrity_set":"max","robbie_battery_refill":true} | 20 |
| svc_engine | Officina di bordo | 1 Lubrificante | {"efficient_flights":5,"fuel_cost_reduction_percent":5} | 30 |
