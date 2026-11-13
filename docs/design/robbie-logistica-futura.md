# Robbie: logistica e squadra futura

Data: 13 novembre 2026.
Stato: scavo manuale, filoni puri e logistica automatica dell'assistente implementati nel prototipo; squadra e fabbricazione di altri Robbie restano future. Il README descrive il runtime attuale.

## Direzione del gioco

- Il personaggio controllato scava ed esplora. Non si introducono estrattori automatici come sostituti dello scavo.
- Il giocatore posa i progetti delle costruzioni desiderate: nella variante umano la sagoma e' gia un ordine completo, senza ritorno obbligato al computer.
- Robbie raccoglie i materiali e li trasporta alla nave. La nave prepara solo i componenti mancanti del primo progetto, riusando prima scorte reali e uscite di ordini gia pagati, anche manuali. Il residuo si arrotonda ai lotti delle ricette esistenti: nessuna scorta minima o produzione speculativa per altri progetti. Gli ingredienti si riservano una sola volta per ordine. Robbie ritira l'uscita pronta dalla nave o dai laboratori, consegna e costruisce sul posto senza trasferimenti manuali di magazzino o pagamenti a distanza.
- I progetti seguono una FIFO stretta nell'ordine originale di posa. Si completa il primo prima di servire il successivo. Se e' bloccato, per esempio da ferro mancante, botola chiusa, uscita piena o energia assente, il motivo concreto viene mostrato e tutta la coda attende: nessun salto a progetti piu facili. Annullare il primo fa avanzare la coda.
- Il computer del laboratorio resta disponibile per stato della coda, scorte e anticipazioni manuali facoltative. Le code di produzione pagate procedono in sequenza per postazione, separatamente dalla FIFO dei progetti; restano vincolanti costi, tempi, energia, capienze e accesso fisico.
- I filoni sono regioni irregolari delimitate, analoghe alle falde come forma ma piene di blocchi solidi di materiale puro. Sono molto duri, finiti e danno grandi quantita di materiale quando scavati.

Confermato: Robbie consegna anche i componenti ai cantieri e costruisce mentre il giocatore continua a scavare. Il primo ciclo automatico riguarda esclusivamente l'umano con Robbie assistente; la variante con Robbie pilotabile mantiene per ora il proprio controllo manuale.

Per il primo laboratorio bastano raccolta di 8 ferro, 3 rame e 1 cristallo, stanza sicura e supportata 4 x 3 m e posa della sagoma. Da scorte vuote la nave prepara 2 lotti strutturali e 1 elettronico, cioe 4 componenti strutturali e 2 elettronici. Robbie pilotabile deve invece ordinare, ritirare e montare manualmente.

La [decisione del 13 novembre](../superpowers/specs/2026-11-13-project-orders-design.md) sostituisce la direzione manuale del 12 novembre: ordinare prima i semilavorati al computer non e' piu un requisito nella variante umano. Fabbricare altri Robbie resta una proposta futura, distinta dalla produzione automatica dei componenti gia disponibile.

## Decisione futura: piu Robbie

Sara possibile fabbricare ulteriori robot Robbie. Non va implementato ora: il primo percorso resta incentrato su un solo assistente, con la possibilita di ampliare la squadra in seguito.

Il futuro sistema di incarichi dovra poter assegnare lavori a robot distinti, senza dipendere da un unico follower globale. Ogni robot avra identita, posizione, carico e incarico propri. Materiali e incarichi dovranno essere prenotati per evitare doppie raccolte, consegne duplicate o consumo multiplo delle stesse scorte.

Possibili ruoli da valutare: raccolta, trasporto alla nave e rifornimento dei cantieri. Specializzazioni, limiti numerici, costi, energia, sblocchi e priorita non sono ancora decisi.

La variante con Robbie controllato dal giocatore resta supportata: il robot pilotato e gli eventuali assistenti autonomi dovranno avere ruoli distinti.

Non si aggiungono ancora ricette, icone, sblocchi o voci nella mappa runtime della produzione. Questi dati andranno aggiornati quando la fabbricazione dei nuovi Robbie verra progettata e implementata.
