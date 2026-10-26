# Geologia Di Ocra

Il prototipo usa 48 x 24 celle da un metro, x da -24 a 23, profondita da 0 a 23. La botola e sull'asse x=0. Il terreno sotto la nave e integro all'atterraggio: soltanto le cavita naturali sigillate sono vuote.

## Strati E Filoni

- 0-4 m: soprattutto terra, con rame dai 2 m.
- 5-14 m: pietra, rame e cristalli. Il percorso del tutorial nei primi 8 m attorno alla botola conserva la disponibilita effettivamente scavabile di 6 pietra e 4 rame.
- Da 15 m: roccia compatta, salvo i filoni. Richiede uno strumento compatibile, non e indistruttibile.
- Massicci e fondo a 23 m: nuclei indistruttibili, anche con Plasma. I massicci si aggirano; non e stato introdotto un nuovo blocco trasversale completo di Ocra.

`scripts/data/ocra_geology.gd` contiene filoni ellittici di rame/cristallo e rettangoli dei massicci. `dig_site.gd` applica prima cavita, poi nuclei, filoni, strati e campionamento locale. Non cambiare le dimensioni del mondo senza aggiornare i controlli dei salvataggi e della navigazione.

## Sacche

Origine e ingombro sono celle intere in `scripts/data/hazard_layout.gd`.

| ID | Contenuto | Origine | Ingombro |
| --- | --- | --- | --- |
| gas_west | Gas | -9, 2 | 2 x 2 |
| water_east | Acqua | 3, 3 | 2 x 2 |
| water_deep | Acqua | -14, 11 | 3 x 2 |
| gas_deep | Gas | 11, 11 | 2 x 2 |
| oil_west | Petrolio | -13, 17 | 3 x 2 |
| oil_east | Petrolio | 6, 16 | 3 x 2 |

Ogni cella contiene inizialmente un volume unitario finito. I liquidi scendono e si livellano solo attraverso aria scavata, senza sovrapporre piu di un volume di acqua + petrolio. Il petrolio e viscoso: massimo 0.15 volumi in caduta e 0.04 lateralmente per passo di 0.2 s. Il gas diffonde e si disperde lentamente dopo l'apertura; le altre sacche sigillate non decadono.

Scanner e Robbie distinguono i tre contenuti. L'acqua sommerge, il gas danneggia la tuta e il petrolio la contamina con 4 danni/s al contatto. Robbie attende fuori dai liquidi. Pompa e ventilatore non estraggono petrolio; un'area contaminata impedisce di attivare le strutture. Non sono ancora implementati raccolta di petrolio, raffinazione o incendi.

## Luce E Salvataggi

La luce personale si restringe e si attenua progressivamente fra 2 e 16 m, senza cambiare portata o potenza degli strumenti. Lampade e laboratori alimentati conservano il loro raggio: le gallerie lontane dal giocatore diventano buie senza illuminazione installata.

I nuovi avamposti salvano `layout_version: 1`, i fluidi `version: 2` con campo `oil`. Salvataggi senza `layout_version` usano la geologia precedente (versione 0, due sacche): non ricevono nuovi ostacoli o cavita nei tunnel gia scavati. Il lettore mantiene compatibilita con fluidi v1 senza petrolio. Modifiche future incompatibili alla mappa richiedono una nuova versione e un percorso esplicito di compatibilita, non una sostituzione silenziosa dei vecchi mondi.

Verifica: `tests/unit/test_ocra_geology.gd`, `tests/unit/test_environment_field.gd`, `tests/integration/ocra_world_smoke.gd` e `tests/integration/ocra_onboarding_smoke.gd`.
