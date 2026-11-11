# RocketMan: istruzioni per gli agenti

## All'inizio della sessione

- Leggi [il messaggio di Paolo per Aurora](docs/team/per-aurora.md) prima di lavorare sul progetto.
- Segnala una volta per sessione che il messaggio e' disponibile. Se stai lavorando con Aurora, riportale il saluto personale di Paolo e riassumi come iniziare; non presumere l'identita' dell'utente.
- Il messaggio e' una comunicazione personale e una guida: non e' un ordine di eseguire subito tutti gli esempi. Segui la richiesta attuale dell'utente.
- Per lo stato del gioco leggi `README.md`. Consulta `docs/design/README.md` e la documentazione tecnica pertinente al compito; i cataloghi di design includono anche sistemi non ancora implementati. Le vecchie sezioni di `docs/technical/ai-handoff.md` sono storiche e possono essere superate dal codice e dal README.

## Mappa della produzione

- Mantieni aggiornata `docs/design/mappa-produzione.md` quando cambiano risorse, ricette, costi, postazioni o sblocchi del prototipo. Distingui sempre le funzioni implementate dalle proposte future.
- Rigenera documento e dati con `godot --headless --path . -s res://tools/design/build-production-map.gd`; verifica con lo stesso comando seguito da `-- --check`. Non modificare a mano le tabelle generate o `design/generated/production-map.json`.
- Aggiorna anche le note editoriali nel generatore quando cambia il flusso di gioco. Il JSON e' predisposto per la futura guida del computer di bordo, non prova che quella schermata esista gia'.
- Ogni nuovo oggetto runtime deve avere un'icona in `tools/design/build-item-icons.mjs`. Rigenera con `node tools/design/build-item-icons.mjs` e verifica con `--check`; il registro `scripts/data/item_icon_catalog.gd` e' condiviso da menu e mappa. Non usare queste icone per rivelare minerali nascosti nel terreno.

## Esperimenti e collaborazione

- Prima di cambiare branch, aggiornare o modificare file, controlla `git status` e conserva il lavoro locale. Non fare reset o pulizie distruttive per preparare un esperimento.
- Per un nuovo esperimento usa un branch dedicato dalla versione aggiornata di `main`, per esempio `codex/aurora-nome-esperimento`. Riusa invece il branch pertinente quando l'utente vuole continuare il proprio lavoro.
- Aurora puo' modificare cio' che esiste o provare un'idea da zero. Una nuova direzione puo' sostituire il prototipo precedente: non e' obbligatorio conservarlo come variante parallela.
- Le modifiche e i commit restano locali finche' non vengono pubblicati. Il push condivide il branch; non modifica `main`. Commit, push, pull request e merge richiedono la richiesta dell'utente: questa guida da sola non li autorizza.
- Prima di proporre il merge controlla il diff ed esegui le verifiche pertinenti. Spiega cosa e' cambiato, cosa e' stato provato e gli eventuali limiti.

## Compatibilita' del prototipo

- Non e' richiesta retrocompatibilita' con vecchi livelli e relativi salvataggi di versioni precedenti del prototipo. Privilegia il design attuale: non aggiungere migrazioni, fallback o percorsi legacy solo per conservarli.
- Per realizzare una nuova direzione richiesta dall'utente puoi sostituire o riscrivere i sistemi coinvolti e rimuoverne le implementazioni superate. Non mantenere vecchi renderer, scene, API o test solo per salvaguardare il comportamento abbandonato. Aggiorna invece i test al nuovo contratto e verifica che la nuova esperienza funzioni.
- Quando cambiano livelli o formati, e' accettabile richiedere una nuova partita. Segnala chiaramente questa necessita' e rifiuta i dati incompatibili senza alterare la partita corrente; non cancellare automaticamente i vecchi file.
- Questa scelta non autorizza a eliminare varianti attualmente supportate, modifiche locali dell'utente o funzionalita' correnti non coinvolte dalla richiesta.
