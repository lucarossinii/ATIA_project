# ATIA_project

Applicazione MATLAB che riconosce gli ingredienti inquadrati da una fotocamera e genera una ricetta che li utilizza.

1. La GUI mostra il flusso live di una fotocamera di rete e permette di scattare una o più foto.
2. Ogni foto viene classificata con **ResNet-50** (usata come estrattore di feature) e con un classificatore **ECOC one-vs-all a SVM lineari**, addestrato su 56 classi di ingredienti.
3. Gli ingredienti riconosciuti con sufficiente sicurezza vengono inviati all'API **Google Gemini**, che restituisce la ricetta mostrata nella GUI.

## Stato delle funzionalità

- [x] Acquisizione immagine: stream HTTP da fotocamera di rete, con scatto di più foto
- [x] Addestramento su dataset: modello salvato in `modello_resnet50_56classi3.mat` (lo script di addestramento non è ancora nel repository)
- [x] Inferenza: classificazione delle foto in `analizza_immagini.m`
- [x] Generazione della ricetta tramite API Gemini

## Struttura del progetto

```text
ATIA_project/
├── main.m                            # punto di ingresso: carica .env e avvia la GUI
├── ATIA.mlapp                        # GUI (App Designer): stream, scatti, analisi e ricetta
├── analizza_immagini.m               # classificazione degli ingredienti (ResNet-50 + ECOC)
├── taratura_soglia.m                 # sceglie la soglia di confidenza su foto di prova etichettate
├── genera_ricetta.m                  # chiamata all'API Google Gemini
├── aumenta_dataset.m                 # data augmentation e bilanciamento del dataset di addestramento
├── modello_resnet50_56classi3.mat    # classificatore addestrato (classifier, featureLayer, imagesize)
├── .env.example                      # modello del file di configurazione
└── .env                              # configurazione locale con la chiave API (da creare, non versionato)
```

## Requisiti

- **MATLAB R2023a o successivo** (serve `loadenv`; l'app è salvata con R2025b)
- **Deep Learning Toolbox**
- Add-On **Deep Learning Toolbox Model for ResNet-50 Network**
- **Statistics and Machine Learning Toolbox**
- **Image Processing Toolbox** solo nelle versioni di MATLAB in cui `imshow` non fa ancora parte di MATLAB base (in R2025b non serve)
- Una **chiave API di Google Gemini**
- Una **fotocamera di rete** che restituisce l'ultimo fotogramma come JPEG via HTTP, ad esempio un'app per smartphone che pubblica `http://<ip>:8080/shot.jpg`, raggiungibile dalla stessa rete del PC

## Configurazione

Copia `.env.example` in `.env` e compila i valori:

```text
API_KEY=la_tua_chiave_gemini
CAMERA_URL=http://192.168.1.9:8080/shot.jpg
# GEMINI_MODEL=gemini-2.5-flash
```

| Variabile      | Obbligatoria | Descrizione |
|----------------|--------------|-------------|
| `API_KEY`      | sì           | chiave dell'API Google Gemini |
| `CAMERA_URL`   | sì           | indirizzo che restituisce l'ultimo fotogramma della fotocamera |
| `GEMINI_MODEL` | no           | modello Gemini da usare (predefinito `gemini-2.5-flash`) |
| `DIAGNOSTICA`  | no           | con `1`, stampa nella Command Window le 3 classi più probabili di ogni foto analizzata |

Il file `.env` è escluso da git tramite `.gitignore`: non va mai committato.

## Utilizzo

Da MATLAB esegui `main.m`, anche se la cartella corrente è un'altra:

```matlab
run("percorso/del/progetto/main.m")
```

oppure, dalla cartella del progetto, semplicemente `main`. Poi, nella finestra:

1. **Avvia** fa partire lo stream live; lo stesso pulsante diventa **Ferma** per interromperlo.
2. **Scatta** salva il fotogramma mostrato. Puoi scattare più foto, ad esempio una per ingrediente.
3. **Genera ricetta** ferma lo stream, riconosce gli ingredienti nelle foto scattate e mostra la ricetta nell'area **Ricetta**, preceduta dall'elenco degli ingredienti riconosciuti.

Dopo una ricetta, la foto successiva inizia una nuova serie. Se qualcosa va storto (fotocamera irraggiungibile, errore dell'API, nessun ingrediente riconosciuto), il messaggio compare nella finestra. In caso di errore le foto scattate restano salvate, quindi puoi riprovare.

## Data augmentation del dataset

`aumenta_dataset.m` crea una copia aumentata e bilanciata del dataset di addestramento (una sottocartella per classe), senza modificare l'originale:

```matlab
aumenta_dataset("dataset", "dataset_aumentato")                          % bilancia sulla classe più numerosa
aumenta_dataset("dataset", "dataset_aumentato", ImmaginiPerClasse=300)   % porta ogni classe a 300 immagini
aumenta_dataset("dataset", "dataset_aumentato", Moltiplicatore=3)        % triplica ogni classe
```

Le immagini generate applicano rotazioni, ribaltamenti, zoom, ritagli, variazioni di colore, rumore, sfocatura e compressione JPEG; `Intensita` ne regola l'ampiezza. Nella cartella di output vengono salvati anche `riepilogo_aumento.csv` (immagini per classe) e `anteprima_aumento.png` (esempi originali e aumentati). Lo script usa solo MATLAB base.

## Come viene calcolata la confidenza

Il classificatore è un ECOC one-vs-all con SVM lineari. Per ogni foto non restituisce una probabilità, ma un **punteggio SVM per ciascuna classe**: è maggiore di 0 se il learner di quella classe la riconosce. La classe predetta è quella con il punteggio più alto.

Come confidenza `analizza_immagini` usa il **margine**, cioè di quanto il punteggio della classe predetta supera quello della seconda classe. Una foto viene accettata se il margine è almeno `SogliaMargine` (predefinito `0.2`). Se un ingrediente compare in più foto, viene inviato una sola volta.

Il margine è più affidabile del punteggio assoluto. Con foto diverse da quelle di addestramento (luce, sfondo, fotocamera) i punteggi si abbassano per tutte le classi, e una soglia sul punteggio assoluto scarta anche le foto riconosciute correttamente. Le versioni precedenti scartavano le foto con punteggio inferiore a `0.4`. Quel valore veniva dalla prima versione del codice, che trattava il punteggio come una probabilità (moltiplicata per 100), e non era mai stato tarato.

Le opzioni si passano come coppie nome-valore:

```matlab
[ingredienti, punteggi, dettagli] = analizza_immagini(foto, SogliaMargine=0.3)
analizza_immagini(foto, SogliaPunteggio=0)        % richiede anche un punteggio minimo della classe predetta
analizza_immagini(foto, RitaglioCentrale=true)    % ritaglia il quadrato centrale invece di schiacciare la foto a 224x224
analizza_immagini(foto, Diagnostica=true)         % stampa le 3 classi più probabili di ogni foto
```

`dettagli` è una tabella con una riga per foto, comprese le foto scartate: contiene la classe, il punteggio, la seconda classe, il margine e l'esito. Con `DIAGNOSTICA=1` nel file `.env` la stampa diagnostica è attiva anche quando le foto vengono analizzate dall'app.

### Taratura della soglia

I valori predefiniti sono provvisori. Per sceglierli sulle foto reali:

1. Scatta alcune foto per ingrediente con la fotocamera dell'app, nelle condizioni d'uso reali. Salvale in una cartella con una sottocartella per ingrediente, chiamata come la classe del modello, ad esempio `foto_prova/pomodoro/`. Non usare foto del dataset di addestramento: su quelle il modello sbaglia molto meno, e la soglia risulterebbe troppo bassa.
2. Esegui la taratura:

   ```matlab
   taratura_soglia("foto_prova")                      % al massimo 10% di ingredienti sbagliati tra quelli accettati
   taratura_soglia("foto_prova", QuotaErrori=0.05)    % al massimo 5%
   ```

3. La funzione mostra:
   - la percentuale di foto riconosciute, con e senza ritaglio centrale;
   - l'effetto di ogni soglia;
   - le confusioni più frequenti;
   - la soglia consigliata.

   Riporta i valori consigliati di `SogliaMargine` e `RitaglioCentrale` come valori predefiniti in `analizza_immagini.m`.

## Limiti noti

- Lo script di addestramento e la descrizione del dataset non sono nel repository, quindi il modello non è riproducibile.
- La soglia di confidenza non è ancora stata tarata: `SogliaMargine = 0.2` è un valore provvisorio (vedi [Taratura della soglia](#taratura-della-soglia)).
- Nel modello `modello_resnet50_56classi3.mat` l'addestramento di almeno 50 dei 56 learner SVM si è fermato con *Iteration limit exceeded*, cioè prima di convergere (con `PassLimit` a 10). Per migliorare il riconoscimento va rifatto aumentando `PassLimit` in `templateLinear` oppure usando `Solver="lbfgs"`. Con `Learner="logistic"` i punteggi diventerebbero probabilità tra 0 e 1, e una soglia in percentuale avrebbe senso.
- Le feature sono l'uscita di `fc1000`, cioè i punteggi delle 1000 classi di ImageNet. Per il transfer learning di solito funzionano meglio quelle di `avg_pool` (2048 valori), che però richiedono di riaddestrare il classificatore.
