# ATIA_project

Applicazione MATLAB che riconosce gli ingredienti inquadrati da una fotocamera e genera una ricetta che li utilizza.

1. La GUI mostra il flusso live di una fotocamera di rete e permette di scattare una o più foto.
2. Ogni foto viene classificata con **ResNet-50** (usata come estrattore di feature) e con un classificatore **ECOC one-vs-all a SVM lineari**, addestrato su 56 classi di ingredienti.
3. Gli ingredienti riconosciuti con sufficiente sicurezza vengono inviati all'API **Google Gemini**, che restituisce la ricetta mostrata nella GUI.

## Stato delle funzionalità

- [x] Acquisizione immagine: stream HTTP da fotocamera di rete, con scatto di più foto
- [x] Addestramento su dataset: modello salvato in `modello_resnet50_56classi2.mat` (lo script di addestramento non è ancora nel repository)
- [x] Inferenza: classificazione delle foto in `analizza_immagini.m`
- [x] Generazione della ricetta tramite API Gemini

## Struttura del progetto

```text
ATIA_project/
├── main.m                            # punto di ingresso: carica .env e avvia la GUI
├── ATIA.mlapp                        # GUI (App Designer): stream, scatti, analisi e ricetta
├── analizza_immagini.m               # classificazione degli ingredienti (ResNet-50 + ECOC)
├── genera_ricetta.m                  # chiamata all'API Google Gemini
├── modello_resnet50_56classi2.mat    # classificatore addestrato (classifier, featureLayer, imagesize)
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

## Come viene calcolata la confidenza

Il classificatore è un ECOC one-vs-all con SVM lineari e non fornisce probabilità. Per ogni foto, `analizza_immagini` usa come misura di confidenza il **punteggio SVM del learner della classe predetta**:

- un valore maggiore di 0 indica che il learner riconosce la classe;
- valori più alti indicano una decisione più netta.

Le predizioni con punteggio inferiore a `0.4` vengono scartate. Il punteggio non è una percentuale, e la soglia va tarata sulle foto reali. Puoi cambiarla passando un secondo argomento a `analizza_immagini(immagini, soglia)` oppure modificando il valore predefinito nella funzione. Se un ingrediente compare in più foto, viene inviato una sola volta.

## Limiti noti

- Lo script di addestramento e la descrizione del dataset non sono nel repository, quindi il modello non è riproducibile.
- La soglia di confidenza (`0.4`) non è stata tarata su un insieme di foto di validazione.
