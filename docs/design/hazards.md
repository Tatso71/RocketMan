# Pericoli e contromisure

Catalogo generato da [hazards.json](../../design/v1/hazards.json). Modificare il JSON e rieseguire `node tools/design/build.mjs`. Numeri di bilanciamento iniziali, da provare nel gioco.

| ID | Pericolo | Fase | Segnale | Danno salute ogni 10 s | Contromisure | Recupero |
| --- | --- | --- | --- | --- | --- | --- |
| haz_darkness | Oscurità | 0 | visor_contrast | 0 | light, scanner | none |
| haz_rubble | Detriti | 1 | loose_fragments | 2 | pulse, support | dig_starter_tool |
| haz_unstable_ceiling | Soffitto instabile | 1 | cracks_dust_10s | 8 | support, alternate_route | rubble_never_item_deletion |
| haz_cold | Gelo | 2 | frost_and_temperature_meter | 3 | heater, insulation, thermal_suit | warm_safe_room |
| haz_ice_slip | Ghiaccio scivoloso | 2 | striped_surface | 1 | traction, ladder | return_path |
| haz_water | Allagamento | 2 | scan_blue_pocket_volume | 0 | pump, tank, drain, airlock | finite_volume_pump |
| haz_drowning | Immersione | 2 | head_under_actual_water_height | 8 | oxygen, swim_up, air_pocket | safe_rescue_cache |
| haz_pressure | Pressione | 2 | depth_gauge_scan | 5 | pressure_cuff, pressure_suit, airlock | withdraw_to_lower_depth |
| haz_spores | Spore irritanti | 3 | purple_motes_scan | 3 | filter, gas_filter, habitat | filter_and_wash |
| haz_toxic_gas | Gas tossico | 3 | scan_yellow_pocket | 5 | filter, gas_filter, door | isolate_and_filter_finite_gas |
| haz_territorial | Stress territoriale | 3 | creature_retreat_posture | 0 | distance, observation, quiet | withdraw_no_combat |
| haz_electric | Scariche | 3 | arcs_audio_and_ground_marker | 6 | magnetic_shield, grounded_cable | safe_grounded_route |
| haz_magnetic_storm | Tempesta magnetica | 3 | sky_warning_30s | 4 | magnetic_shield, ship_shelter | wait_in_shelter |
| haz_heat | Calore | 4 | heat_haze_temperature_meter | 5 | heat_shield, coolant, heater | cooled_room |
| haz_lava | Magma | 4 | visible_glow_scan_solid_margin | 25 | bypass, bridge, support | no_required_ore_inside_magma |
| haz_vent | Sfiato ciclico | 4 | rising_bubbles_hiss_cycle | 12 | time_window, heat_shield | timed_crossing_safe_alcove |
| haz_sandstorm | Tempesta di sabbia | 4 | horizon_warning_30s | 3 | shelter, filter, ship | wait_in_shelter |
| haz_abrasion | Abrasione | 4 | dust_wear_meter | 2 | sealed_suit, patch, airlock | repair_at_station |
| haz_dehydration | Stress da aridità | 4 | thermal_route_budget_warning | 2 | coolant, water, rest | single_expedition_ration_not_thirst_spam |
| haz_resonance | Risonanza instabile | 5 | pulsing_wave_8s | 8 | resonator, damping, alternate_route | calibrate_from_safe_edge |
| haz_shards | Schegge minerali | 5 | crystal_rattle_5s | 10 | shield, support, distance | collect_after_settling |
| haz_wind | Corrente ascensionale | 5 | ribbons_and_direction_arrows | 3 | stabilizer, anchor, alternate_route | safety_tether_prevents_void_fall |
| haz_thin_air | Atmosfera rarefatta | 5 | oxygen_density_scan | 0 | oxygen, life_support, pressure_frame | portable_oxygen_budget |
| haz_radiation | Radiazioni | 6 | geiger_visual_and_dose | 4 | iridium_frame, radiation_suit, shield | dose_recovers_at_infirmary |
| haz_silence | Disturbo di segnale | 6 | radio_fade_and_map_quality | 0 | beacon, relay, optical_link | robbie_waits_at_safe_node_with_cargo |
| haz_mixed_fields | Campi combinati | 7 | scanner_three_separate_channels | 6 | three_previously_learned_counters | never_more_than_two_active_damage_sources |
