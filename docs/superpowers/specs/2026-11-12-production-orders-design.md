# Ordini di produzione e Robbie esecutore

Data: 12 novembre 2026.
Stato: computer e ordini manuali implementati. Il requisito di ordinare prima i
semilavorati e' stato sostituito il 13 novembre dal progetto come ordine completo;
vedere `2026-11-13-project-orders-design.md`. Il computer resta facoltativo.

## Intento

Il giocatore decide quali semilavorati produrre e in quale quantita.
Robbie esegue la logistica e il montaggio, lasciando il giocatore libero di
scavare. Posare un progetto non deve ordinare implicitamente componenti.

## Approcci

- Produzione automatica secondo cantieri e scorta minima: comportamento del
  prototipo attuale, sostituito perche il giocatore vuole decidere la produzione.
- Produzione su ordine esplicito, logistica e montaggio automatici: direzione
  scelta dall'utente. Nessuna necessita di trasferire manualmente il magazzino.

## Flusso Proposto

1. Tasto destro sul laboratorio di bordo apre il computer della postazione.
2. Il pannello mostra semilavorati, resa, quantita ordinabile, durata e
   ingredienti con icone e conteggi hai/servono. Mostra anche produzione in
   corso, scorte pronte e incarico/blocco di Robbie.
3. Il giocatore ordina lotti di componenti strutturali o elettronici. Si
   riutilizzano ricette, costi, energia e produzione a tempo esistenti.
4. Gli ordini vengono lavorati in sequenza. Proposta implementativa: un ordine
   e' accettato solo se gli ingredienti sono gia disponibili alla postazione;
   vengono riservati una volta, senza ordini fantasma o doppio pagamento.
5. Robbie continua a raccogliere e portare i minerali alla nave. Non sceglie
   ricette e non mantiene una scorta minima di componenti di propria iniziativa.
6. Il giocatore posa il progetto del laboratorio o di un dispositivo. Quando
   i componenti sono pronti, Robbie li carica, li porta sul posto e costruisce.
7. Se mancano semilavorati, il progetto indica quali ordinare; se mancano
   minerali, energia o passaggi, il pannello espone il motivo concreto.

Per il primo laboratorio: due lotti strutturali e un lotto elettronico,
ottenendo 4 componenti strutturali e 2 elettronici da 8 ferro, 3 rame e
1 cristallo. Nessun cambiamento ai costi.

## Confini

- Automazione di consegna e montaggio solo nella variante umano con assistente.
  Robbie pilotabile resta manuale come richiesto in precedenza.
- Restano vincolanti capienza, percorso fisico, ingombro, supporto ed energia.
- Ordini, materiali riservati e lavorazioni pagate devono sopravvivere a
  salvataggio/caricamento senza duplicazioni. Nessuna migrazione dei vecchi livelli.
- Nessun nuovo minerale, semilavorato o robot. Si riusa l'interfaccia Godot e
  il catalogo delle icone esistenti, senza introdurre un secondo inventario.
- Aggiornare tutorial, README, logistica e mappa di produzione insieme al codice.
- Nessun commit, push, merge o riavvio della partita senza una nuova richiesta.
