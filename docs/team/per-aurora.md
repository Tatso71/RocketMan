# Per Aurora, da Paolo

5 novembre 2026

## Prima di tutto

Aurora, ti voglio bene.

Mi piacerebbe che ti divertissi a inventare questo gioco insieme a me. Puoi fare i tuoi esperimenti liberamente: partire da un'idea nuova oppure cambiare quello che esiste gia'. Non devi seguire per forza tutte le scelte fatte finora.

Paolo

## Come iniziare

Apri RocketMan in Codex e parlaci come fai gia' per il lavoro: descrivi l'idea, chiedi una modifica, prova il risultato e poi raccontagli cosa vuoi cambiare. Per cominciare non serve scrivere codice a mano o conoscere tutti i comandi Git.

Puoi chiedergli:

> Leggi AGENTS.md, il messaggio di Paolo per Aurora e il README. Controlla se ho modifiche locali da conservare, aggiorna main e crea da li' un nuovo branch per i miei esperimenti, chiamato codex/aurora-primo-esperimento. Non fare commit, push o merge finche' non te lo chiedo.

Se hai gia' iniziato un esperimento, chiedigli invece di riprendere quel branch senza perdere le modifiche. Se il pull e' avvenuto in una chat gia' aperta che non ha ancora letto il messaggio, puoi scrivere: "Leggi AGENTS.md e docs/team/per-aurora.md". Il pull scarica i file, non avvia da solo l'AI.

## Il tuo spazio per sperimentare

Un branch e' una linea di lavoro separata da `main`, la versione condivisa del progetto. Puoi partire dalla versione attuale e modificarla, oppure chiedere a Codex una scena o una variante nuova da zero, conservando il gioco esistente.

Il branch non e' una seconda cartella: prima di cambiarlo fai controllare e conservare a Codex l'eventuale lavoro non salvato in commit. Non serve cancellare file o ricominciare la storia Git.

Per esempio:

> Vorrei inventare una versione diversa del primo pianeta. Facciamo una scena separata e proviamola senza sostituire quella attuale.

> Vorrei rendere piu' chiari i messaggi di Robbie. Mostrami dove si modificano e aiutami a riscriverli.

> Vorrei provare una nuova meccanica. Prima ragioniamoci insieme, senza cambiare ancora il codice.

> Applica questa idea sul mio branch e poi avvia il gioco in Godot, cosi' la provo.

## Quando il lavoro diventa condiviso

1. **Modifiche ai file:** sono sul tuo computer e non cambiano il repository remoto.
2. **Commit:** salva una versione nella storia Git locale. Da solo non la pubblica.
3. **Push:** pubblica i commit sul tuo branch GitHub. Paolo puo' vederli, ma `main` rimane invariato.
4. **Pull request:** permette di vedere e discutere le differenze prima di unirle.
5. **Merge su main:** integra il lavoro nella versione condivisa. Gli altri lo ricevono aggiornando `main` con un pull.

Puoi quindi sperimentare senza pubblicare subito. Quando vuoi condividere, chiedi a Codex di verificare le modifiche e fare commit e push del tuo branch. Quando siete pronti a integrarle, chiedigli di aprire una pull request e fare il merge su `main`, controllando eventuali conflitti.

Un commit locale e' utile per conservare una tappa, ma non e' un backup remoto: per avere una copia su GitHub serve il push, anche senza fare il merge.

## Da dove riprendere il gioco

Il prototipo attuale e' in Godot 4: scegli un pianeta, atterri con una nave-casa di tre piani e scavi gallerie sotto di essa. Ocra e' il primo pianeta/tutorial. Ci sono materiali, laboratori costruibili, macchine, luci, energia e falde di acqua, acido, petrolio e gas.

All'inizio puoi scegliere **Umano** o **Robbie**. Nella variante Robbie guidi il robot e al piano centrale dormono in capsule uno scienziato biomedico, una scienziata botanica/chimica e un gatto. Puoi sviluppare una delle due varianti o inventarne un'altra.

- Apri `project.godot` in Godot e premi **F5** per il gioco completo, inclusa la scelta del personaggio. **Arriva subito al pianeta** salta le scene di viaggio.
- Il [README](../../README.md) descrive lo stato attuale, i comandi e i test.
- Il [design completo](../design/README.md) raccoglie le idee e i cataloghi: non tutto e' gia' realizzato e non e' un vincolo per i tuoi esperimenti.
- Per i testi di Robbie c'e' `scenes/labs/robbie_text_lab.tscn`, da eseguire con **F6**; i messaggi sono in `design/v1/robbie_texts.json`.

Parti dalla cosa che ti incuriosisce di piu'. Il gioco possiamo inventarlo parlandone, un esperimento alla volta.
