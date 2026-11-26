function [ingredienti, punteggi, dettagli, classi] = analizza_immagini(immagini, opzioni)
% ANALIZZA_IMMAGINI Riconosce gli ingredienti presenti in una o più immagini.
%
%   ingredienti = ANALIZZA_IMMAGINI(immagini) classifica ogni immagine con
%   ResNet-50 (usata come estrattore di feature) e con il classificatore
%   salvato in modello_resnet50_56classi3.mat, e restituisce gli
%   ingredienti riconosciuti con sufficiente sicurezza, senza duplicati.
%
%   [ingredienti, punteggi, dettagli, classi] = ANALIZZA_IMMAGINI(immagini, Nome=Valore)
%   accetta le opzioni:
%     SogliaMargine    - distacco minimo tra il punteggio della classe
%                        predetta e quello della seconda classe più
%                        probabile (predefinito 0.2, vedi "Confidenza")
%     SogliaPunteggio  - punteggio minimo della classe predetta
%                        (predefinito -Inf, cioè nessun limite)
%     RitaglioCentrale - se true ritaglia il quadrato centrale della foto
%                        prima di ridimensionarla a 224x224, invece di
%                        schiacciarla (predefinito false)
%     Diagnostica      - se true stampa nella Command Window, per ogni
%                        foto, le tre classi con il punteggio più alto e
%                        l'esito (predefinito true solo se la variabile
%                        d'ambiente DIAGNOSTICA vale 1, ad esempio nel
%                        file .env)
%
%   Input:
%     immagini - cell array di immagini ({img1, img2, ...}), una singola
%                immagine, oppure string array / cell array di percorsi
%                di file (["a.jpg", "b.jpg"])
%
%   Output:
%     ingredienti - string array colonna, senza duplicati, nell'ordine in
%                   cui gli ingredienti compaiono nelle foto
%     punteggi    - margine di ciascun ingrediente (il più alto tra le
%                   foto in cui compare)
%     dettagli    - tabella con una riga per foto, comprese le scartate:
%                   Classe, Punteggio, SecondaClasse, Margine, Accettata
%     classi      - classi che il modello sa riconoscere
%
%   Confidenza: il classificatore è un ECOC one-vs-all con SVM lineari e
%   non fornisce probabilità, ma un punteggio SVM per ogni classe
%   (maggiore di 0 se il learner di quella classe la riconosce). La classe
%   predetta è quella con il punteggio più alto; come confidenza si usa il
%   margine, cioè di quanto supera la seconda classe. Il margine dipende
%   meno dalle condizioni della foto rispetto al punteggio assoluto, che
%   con foto diverse da quelle di addestramento (luce, sfondo, fotocamera)
%   tende ad abbassarsi per tutte le classi. I valori predefiniti delle
%   soglie sono provvisori: vanno tarati con taratura_soglia su foto
%   scattate con la fotocamera dell'app.

    arguments
        immagini
        opzioni.SogliaMargine (1,1) double = 0.2
        opzioni.SogliaPunteggio (1,1) double = -Inf
        opzioni.RitaglioCentrale (1,1) logical = false
        opzioni.Diagnostica (1,1) logical = strcmp(getenv("DIAGNOSTICA"), "1")
    end

    % Carica modello e rete una sola volta, poi li riusa nelle chiamate
    % successive
    persistent net modello
    if isempty(net) || isempty(modello)
        fileModello = fullfile(fileparts(mfilename("fullpath")), "modello_resnet50_56classi3.mat");
        modello = load(fileModello, "classifier", "featureLayer", "imagesize");
        verificaModello(modello.classifier);
        net = resnet50();
    end

    % Uniforma l'input in un cell array
    if isstring(immagini) || ischar(immagini)
        immagini = cellstr(immagini);
    elseif isnumeric(immagini) || islogical(immagini)
        immagini = {immagini};
    end

    classi = string(modello.classifier.ClassNames);
    numFoto = numel(immagini);
    classe = strings(numFoto, 1);
    punteggio = zeros(numFoto, 1);
    secondaClasse = strings(numFoto, 1);
    margine = zeros(numFoto, 1);
    accettata = false(numFoto, 1);

    for i = 1:numFoto
        img = immagini{i};

        % Se l'elemento è il percorso di un file, legge l'immagine
        if ischar(img) || isstring(img)
            img = imread(img);
        end

        if opzioni.RitaglioCentrale
            img = ritaglioQuadrato(img);
        end

        % Ridimensiona a 224x224 come in addestramento
        ds = augmentedImageDatastore(modello.imagesize, img, ...
            'ColorPreprocessing', 'gray2rgb');

        % Estrazione delle feature
        features = activations(net, ds, modello.featureLayer, ...
            'MiniBatchSize', 1, 'OutputAs', 'columns');

        % Il terzo output di predict per un modello ECOC è PBScore: un
        % punteggio per ogni learner binario. Con la codifica one-vs-all
        % il learner k corrisponde alla classe k.
        [label, ~, pbScore] = predict(modello.classifier, features, ...
            'ObservationsIn', 'columns');

        k = find(classi == string(label), 1);
        altri = pbScore;
        altri(k) = -Inf;
        [punteggioSeconda, k2] = max(altri);

        classe(i) = classi(k);
        punteggio(i) = pbScore(k);
        secondaClasse(i) = classi(k2);
        margine(i) = pbScore(k) - punteggioSeconda;
        accettata(i) = margine(i) >= opzioni.SogliaMargine && ...
            punteggio(i) >= opzioni.SogliaPunteggio;

        if opzioni.Diagnostica
            stampaDiagnostica(i, numFoto, classi, pbScore, margine(i), ...
                accettata(i), opzioni);
        end
    end

    dettagli = table((1:numFoto)', classe, punteggio, secondaClasse, ...
        margine, accettata, 'VariableNames', ...
        ["Foto", "Classe", "Punteggio", "SecondaClasse", "Margine", "Accettata"]);

    % Ingredienti accettati, senza duplicati: se un ingrediente compare in
    % più foto tiene il margine più alto
    ingredienti = strings(0, 1);
    punteggi = zeros(0, 1);
    for i = find(accettata)'
        idx = find(ingredienti == classe(i), 1);
        if isempty(idx)
            ingredienti(end+1, 1) = classe(i); %#ok<AGROW>
            punteggi(end+1, 1) = margine(i); %#ok<AGROW>
        else
            punteggi(idx) = max(punteggi(idx), margine(i));
        end
    end
end

function img = ritaglioQuadrato(img)
% Ritaglia il quadrato centrale dell'immagine, con lato pari al lato minore
    [h, w, ~] = size(img);
    lato = min(h, w);
    r = floor((h - lato) / 2);
    c = floor((w - lato) / 2);
    img = img(r+1:r+lato, c+1:c+lato, :);
end

function stampaDiagnostica(i, numFoto, classi, pbScore, margine, accettata, opzioni)
% Stampa le tre classi con il punteggio più alto e l'esito della foto
    [ordinati, ordine] = sort(pbScore(:), 'descend');
    n = min(3, numel(ordinati));
    migliori = join(classi(ordine(1:n)) + " " + compose("%.2f", ordinati(1:n)), " | ");

    if accettata
        esito = "accettata";
    elseif margine < opzioni.SogliaMargine
        esito = sprintf("scartata (margine sotto %.2f)", opzioni.SogliaMargine);
    else
        esito = sprintf("scartata (punteggio sotto %.2f)", opzioni.SogliaPunteggio);
    end

    fprintf("Foto %d/%d: %s -> margine %.2f, %s\n", i, numFoto, migliori, margine, esito);
end

function verificaModello(classifier)
% Il calcolo della confidenza presume un ECOC con codifica one-vs-all:
% una colonna della matrice di codifica per classe, con +1 sulla
% diagonale e -1 altrove.
    numClassi = numel(classifier.ClassNames);
    codificaOneVsAll = 2 * eye(numClassi) - 1;
    if ~isequal(classifier.CodingMatrix, codificaOneVsAll)
        error("analizza_immagini:codificaNonSupportata", ...
            "Il classificatore non usa la codifica one-vs-all: " + ...
            "il calcolo della confidenza in analizza_immagini va adattato.");
    end
end
