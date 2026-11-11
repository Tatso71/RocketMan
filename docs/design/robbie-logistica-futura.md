# Robbie: logistica e squadra futura

Data: 11 novembre 2026.
Stato: scavo manuale, filoni puri e logistica automatica dell'assistente implementati nel prototipo; squadra e fabbricazione di altri Robbie restano future. Il README descrive il runtime attuale.

## Direzione del gioco

- Il personaggio controllato scava ed esplora. Non si introducono estrattori automatici come sostituti dello scavo.
- Robbie raccoglie i materiali, li trasporta alla nave e ne gestisce la conversione senza ordini manuali ripetitivi o trasferimenti di magazzino da parte del giocatore.
- Il giocatore posa i progetti delle costruzioni desiderate.
- I filoni sono regioni irregolari delimitate, analoghe alle falde come forma ma piene di blocchi solidi di materiale puro. Sono molto duri, finiti e danno grandi quantita di materiale quando scavati.

Confermato: Robbie consegna anche i componenti ai cantieri e costruisce mentre il giocatore continua a scavare. Il primo ciclo automatico riguarda esclusivamente l'umano con Robbie assistente; la variante con Robbie pilotabile mantiene per ora il proprio controllo manuale.

## Decisione futura: piu Robbie

Sara possibile fabbricare ulteriori robot Robbie. Non va implementato ora: il primo percorso resta incentrato su un solo assistente, con la possibilita di ampliare la squadra in seguito.

Il futuro sistema di incarichi dovra poter assegnare lavori a robot distinti, senza dipendere da un unico follower globale. Ogni robot avra identita, posizione, carico e incarico propri. Materiali e incarichi dovranno essere prenotati per evitare doppie raccolte, consegne duplicate o consumo multiplo delle stesse scorte.

Possibili ruoli da valutare: raccolta, trasporto alla nave e rifornimento dei cantieri. Specializzazioni, limiti numerici, costi, energia, sblocchi e priorita non sono ancora decisi.

La variante con Robbie controllato dal giocatore resta supportata: il robot pilotato e gli eventuali assistenti autonomi dovranno avere ruoli distinti.

Non si aggiungono ancora ricette, icone, sblocchi o voci nella mappa runtime della produzione. Questi dati andranno aggiornati quando la fabbricazione dei nuovi Robbie verra progettata e implementata.
