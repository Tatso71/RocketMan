# Prese Stagne E Circuiti Dell'Acqua

## Design Approvato

La presa con valvola controlla il passaggio attraverso un blocco di confine; la pompa separata trasferisce acqua consumando energia. Non sono livelli successivi dello stesso oggetto. Si usano componenti prodotti dal laboratorio e montaggio locale. Le scale restano gratuite; non aggiungiamo pavimenti o volumi costruibili.

La presa occupa una cella libera ed e' fissata a una faccia di una roccia adiacente. Si monta chiusa, si collega al tubo, si perfora in modo stagno e si apre esplicitamente. Il foro attraversa un solo blocco senza scavarlo e senza rilasciare la falda. Le quattro direzioni sono valide; roccia indistruttibile e materiali oltre il tool attuale non sono perforabili.

I tubi non perdono da estremita' non configurate. Un terminale di scarico e' una funzione del tubo, non un terzo macchinario da fabbricare: scarica in una cella libera adiacente scelta dal giocatore. Il liquido diventa acqua fisica del mondo, riempie e puo' traboccare dalla vasca scavata. Lo spazio saturo/ostruito ferma il trasferimento senza cancellare acqua. Senza tubo la valvola torna chiusa. Rompere l'ancoraggio distrugge la tenuta e apre normalmente la falda.

Completamento della stessa funzione: il terminale puo' essere configurato esplicitamente anche come aspirazione per acqua gia' fuoriuscita o vasche naturali. Non e' un altro macchinario: la scelta di ruolo richiude il terminale e richiede riapertura. Nessun tubo aspira automaticamente da estremita' non configurate.

## Scelte Implementative

- Prima tranche: acqua. Gas/petrolio/acido con prese e pompe dedicate restano futuri; il circuito gas attuale non viene rimosso.
- Presa 1 x 1 m: posa immediata, 2 strutturali + 1 elettronico; sblocco al primo laboratorio. Terminale di scarico gratuito su un tubo gia' pagato; tubi costano ancora 1 strutturale/m.
- Flusso passivo 0.35 u/s: percorso connesso che non salga oltre il livello d'acqua alla presa, uscita piu' bassa. Nessuna simulazione di pressione o sifoni complessi.
- Pompa esistente 2 x 2 m: due porte inferiori distinte, ingresso sinistro e uscita destra; comando per invertirle. 0.7 u/s, dislivello massimo 6 m, buffer finito 8 u, alimentazione attuale dal laboratorio/nave. Nessuna aspirazione magica per raggio.
- La pompa separa le reti di ingresso e uscita. Un tubo costruito attorno alla pompa puo' creare un bypass reale. Portata e quantita' devono conservarsi anche con piu' pompe/scarichi o riceventi pieni.
- La serra riceve dal buffer delle pompe realmente collegate alla propria rete di uscita. Nessun teletrasporto fra reti disconnesse.
- Menu contestuali con aperta/chiusa, perforazione, direzione, stato, portata effettiva, consumo e buffer; preview orientabile e animazione del flusso.
- Salvataggi atomici di prese, terminali, stato delle valvole e orientamento pompe. Nessuna migrazione di vecchi comportamenti; gli stati nuovi vengono validati prima di sostituire il mondo.

## Alternative Considerate

Un solo oggetto valvola/pompa riduce le azioni ma obbliga a pagare energia anche per un semplice collegamento; evolvere la valvola in pompa confonde funzioni diverse. Scelti oggetti separati, individualmente migliorabili in futuro. Serbatoi della nave con bocchettoni e trasporto interplanetario sono approvati come estensione futura, non parte di questa tranche.
