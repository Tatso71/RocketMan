# Compiti di Robbie

Il tutorial di Ocra fino al primo laboratorio e definito in `design/v1/progression.json`, sezione `ocra_tutorial`. Il runtime legge direttamente questi dati; non modificare l'HTML generato per cambiare il gioco.

## Aggiungere Una Tappa

Inserire una voce in `steps`, nell'ordine desiderato. Non occorre aggiungere messaggi o rami nel codice della GUI:

```json
{
  "id": "inspect_bed",
  "title_it": "Controlla il letto",
  "hint_it": "Clic destro sul letto al piano centrale. Potrai tornare qui per recuperare energia e integrita della tuta.",
  "detail_it": "Alloggio / piano centrale",
  "action": "help",
  "complete_when": {"fact": "bed_inspected"}
}
```

Gli ID devono essere univoci e stabili. Titolo e dettaglio compaiono nel pannello obiettivo; `hint_it` e il balloon di Robbie. La numerazione, la barra, il richiamo manuale, la ripetizione ogni 25 secondi e il salvataggio si adattano alla lista. Gli avvisi di pericolo hanno precedenza; silenziare i balloon non nasconde l'obiettivo e non blocca il progresso.

`complete_when` accetta una condizione:

- `{"fact": "nome_evento"}`: un evento semantico e realmente avvenuto.
- `{"counter": "mined_cells", "at_least": 2}`: il contatore ha raggiunto la soglia intera positiva.

Gli eventi gia avvenuti restano validi anche se il giocatore esegue le azioni in un ordine diverso. Non serve ripetere un'azione perche il messaggio non era ancora apparso. `finish_when` termina l'intero percorso: per aggiungere compiti dopo il laboratorio occorre spostare anche questa condizione finale.

## Eventi Disponibili

| Evento | Origine |
| --- | --- |
| `workshop_entered` | Personaggio arrivato al piano inferiore |
| `workshop_interacted` | Apertura dei comandi dell'officina |
| `hatch_opened` | Botola effettivamente aperta |
| `mined` / `mined_cells` | Rimozione riuscita di una cella, non un impulso o una scansione |
| `ladder` | Scala realmente costruita e pagata |
| `inventory_opened` | Inventario aperto da qualsiasi accesso |
| `bed_inspected` | Apertura del pannello del letto |
| `lab_materials_ready` | 6 pietra + 4 rame nel carico comune o nel deposito locale raggiungibile |
| `lab_fabrication_started` | Pagamento unico e lavorazione avviata sul banco |
| `lab_cube_crafted` | Cubo pronto fisicamente sul banco, oppure cubo pagato da un salvataggio precedente |
| `lab_cube_carried` | Cubo preso con Spazio e portato in mano |
| `lab_cube_dropped` | Cubo posato con Spazio prima dell'attivazione |
| `lab_room_ready` | Stanza 4 x 3 libera, asciutta, sostenuta e nel raggio locale |
| `lab_cube_deployed` | Cubo consumato e montaggio iniziato |
| `lab_built` | Laboratorio attivo dopo il montaggio |
| `deposited`, `lamp_crafted`, `lamp_placed`, `pump_built` | Operazioni completate nei sistemi esistenti |

Gli eventi emessi da un'azione riuscita hanno automaticamente anche un contatore con lo stesso nome: `{"counter": "ladder", "at_least": 3}` richiede tre scale costruite. `mined_cells` e l'alias leggibile del contatore `mined`. Le osservazioni continue del mondo aggiornano solo i fatti: non incrementano contatori, e neppure il caricamento di un salvataggio inventa nuove azioni.

Per una nuova azione di gioco emettere una volta `world.guide_event("nome_evento")` solo dopo il successo della transazione; non occorrono modifiche al modello per contarla. Non assegnare esperienza o materiali da un messaggio. Le azioni di pulsante supportate sono `help`, `fabricate_lab`, `place_lab` e `inventory`; comandi nuovi richiedono un gestore esplicito nella GUI.

## Costruzione E Compatibilita

Le nuove partite iniziano senza materiali nella nave, nel giocatore o in Robbie. I due carichi si sommano sempre per disponibilita, pagamento e trasferimenti; il raggio radio continua a limitare il movimento del robot e la raccolta di nuove risorse, non l'uso dei materiali gia trasportati. Il deposito della nave o del laboratorio contribuisce solo quando quel banco e raggiungibile.

La ricetta `recipe_cube_lab` costa 6 pietra + 4 rame e 0.01 kWh. Crea verifica e paga atomicamente all'avvio, riservando il singolo slot di uscita del banco: non occorre spazio nello zaino. La produzione dura 5 / 3.33 / 2.5 secondi ai livelli I / II / III del laboratorio e produce attualmente un laboratorio di livello I. Il cubo si materializza sul banco con una barra; il lavoro continua chiudendo il pannello e persiste anche a meta. Un banco sotterraneo spento o senza energia sospende il lavoro pagato senza perderlo.

Spazio vicino al cubo lo prende; Spazio mentre lo si trasporta lo posa senza saltare. Un solo cubo puo stare in mano, separato dalle risorse dello zaino. Durante il trasporto lo strumento non puo scavare. Clic destro sul cubo posato apre Attiva laboratorio: solo ora viene verificato l'intero ingombro 4 x 3. Se non entra, il cubo resta recuperabile con tratteggio rosso e motivo del blocco; non si paga nulla. Se valido, viene consumato quel cubo e parte il montaggio di 5 s. Il personaggio puo stare nell'ingombro.

`fabrication_state.gd` salva lavori pagati, cubi pronti/posati e il cubo in mano. Il banco di bordo e i cubi che viaggiano sulla nave vengono trasferiti allo stato nave al decollo e importati una sola volta al nuovo atterraggio. Le lavorazioni locali restano sul pianeta; non si simulano pianeti non visitati o tempo offline. I vecchi cubi pagati nello zaino vengono materializzati quando si preme Spazio; le scorte reali gia presenti nei salvataggi non vengono cancellate.

I vecchi cantieri non finanziati conservano un comando esplicito di compatibilita con materiali comuni, senza popup automatici. Il solo oggetto nel nuovo pannello e il laboratorio. Luci, pompa asciuga acqua e ventilatore rimuovi gas sono gli sblocchi futuri: non sono offerti oggi; vecchie luci/pompe gia salvate continuano a funzionare. Scale sempre immediate con B, per 2 terra e senza cubo. La progressione completa e lo strato limite di Ocra restano da definire.

## Verifica

```powershell
node tools/design/build.mjs
node tools/design/validate.mjs
node tools/design/check-preview.mjs
godot --headless --path . -s res://tests/integration/ocra_onboarding_smoke.gd
godot --headless --path . -s res://tests/integration/physical_fabrication_smoke.gd
```

Il test attraversa la nave e scava realmente la stanza, senza la fixture di gallerie preesistenti. `-- --capture` senza `--headless` verifica pannello obiettivo, balloon, fabbricazione, distanza di Robbie e laboratorio a 720p/1080p. I test unitari coprono l'aggiunta di un compito dai dati, ordine libero, richiamo, priorita dei pericoli e salvataggi nativi/JSON.
