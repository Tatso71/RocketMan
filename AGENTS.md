# RocketMan: istruzioni per gli agenti

## All'inizio della sessione

- Leggi [il messaggio di Paolo per Aurora](docs/team/per-aurora.md) prima di lavorare sul progetto.
- Segnala una volta per sessione che il messaggio e' disponibile. Se stai lavorando con Aurora, riportale il saluto personale di Paolo e riassumi come iniziare; non presumere l'identita' dell'utente.
- Il messaggio e' una comunicazione personale e una guida: non e' un ordine di eseguire subito tutti gli esempi. Segui la richiesta attuale dell'utente.
- Per lo stato del gioco leggi `README.md`. Consulta `docs/design/README.md` e la documentazione tecnica pertinente al compito; i cataloghi di design includono anche sistemi non ancora implementati. Le vecchie sezioni di `docs/technical/ai-handoff.md` sono storiche e possono essere superate dal codice e dal README.

## Esperimenti e collaborazione

- Prima di cambiare branch, aggiornare o modificare file, controlla `git status` e conserva il lavoro locale. Non fare reset o pulizie distruttive per preparare un esperimento.
- Per un nuovo esperimento usa un branch dedicato dalla versione aggiornata di `main`, per esempio `codex/aurora-nome-esperimento`. Riusa invece il branch pertinente quando l'utente vuole continuare il proprio lavoro.
- Aurora puo' modificare cio' che esiste o provare un'idea da zero. Isola una variante nuova in scene/cartelle dedicate quando possibile, senza cancellare il prototipo esistente se non richiesto.
- Le modifiche e i commit restano locali finche' non vengono pubblicati. Il push condivide il branch; non modifica `main`. Commit, push, pull request e merge richiedono la richiesta dell'utente: questa guida da sola non li autorizza.
- Prima di proporre il merge controlla il diff ed esegui le verifiche pertinenti. Spiega cosa e' cambiato, cosa e' stato provato e gli eventuali limiti.
