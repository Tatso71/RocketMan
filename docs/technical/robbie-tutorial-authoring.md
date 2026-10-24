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
| `lab_cube_crafted` | Cubo fisico fabbricato, oppure gia presente nel carico |
| `lab_room_ready` | Stanza 4 x 3 libera, asciutta, sostenuta e nel raggio locale |
| `lab_cube_deployed` | Cubo consumato e montaggio iniziato |
| `lab_built` | Laboratorio attivo dopo il montaggio |
| `deposited`, `lamp_crafted`, `lamp_placed`, `pump_built` | Operazioni completate nei sistemi esistenti |

Gli eventi emessi da un'azione riuscita hanno automaticamente anche un contatore con lo stesso nome: `{"counter": "ladder", "at_least": 3}` richiede tre scale costruite. `mined_cells` e l'alias leggibile del contatore `mined`. Le osservazioni continue del mondo aggiornano solo i fatti: non incrementano contatori, e neppure il caricamento di un salvataggio inventa nuove azioni.

Per una nuova azione di gioco emettere una volta `world.guide_event("nome_evento")` solo dopo il successo della transazione; non occorrono modifiche al modello per contarla. Non assegnare esperienza o materiali da un messaggio. Le azioni di pulsante supportate sono `help`, `fabricate_lab`, `place_lab` e `inventory`; comandi nuovi richiedono un gestore esplicito nella GUI.

## Costruzione E Compatibilita

Il laboratorio usa la ricetta `recipe_cube_lab`: fabbricazione di 5 s in officina, 6 pietra + 4 rame e 0.01 kWh. Il pagamento avviene alla conclusione dopo una nuova verifica di ingredienti e spazio. Chiudere il menu annulla un assemblaggio non completato senza costi; non esiste un lavoro pagato nascosto da ripristinare. Il cubo occupa 4 posti in un solo contenitore, non puo essere diviso fra zaino e Robbie. Posarlo consuma un cubo e avvia il montaggio di 5 s, senza un secondo pagamento; il montaggio pagato e persistente anche a meta.

I vecchi cantieri gia posati e non finanziati mantengono la richiesta di materie sul posto; non vengono convertiti o addebitati di nuovo. Luci e pompe mantengono il precedente flusso di finanziamento locale in questa tranche. Il resto del catalogo completo, la nuova progressione planetaria e l'eventuale strato limite di Ocra non sono implementati da questo tutorial.

## Verifica

```powershell
node tools/design/build.mjs
node tools/design/validate.mjs
node tools/design/check-preview.mjs
godot --headless --path . -s res://tests/integration/ocra_onboarding_smoke.gd
```

Il test attraversa la nave e scava realmente la stanza, senza la fixture di gallerie preesistenti. `-- --capture` senza `--headless` verifica pannello obiettivo, balloon, fabbricazione, distanza di Robbie e laboratorio a 720p/1080p. I test unitari coprono l'aggiunta di un compito dai dati, ordine libero, richiamo, priorita dei pericoli e salvataggi nativi/JSON.
