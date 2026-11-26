function [ingredienti, punteggi] = analizza_immagini(immagini, sogliaPunteggio)
% ANALIZZA_IMMAGINI Riconosce gli ingredienti presenti in una o più immagini.
%
%   ingredienti = ANALIZZA_IMMAGINI(immagini) classifica ogni immagine con
%   ResNet-50 (usata come estrattore di feature) e con il classificatore
%   salvato in modello_resnet50_56classi2.mat, e restituisce gli
%   ingredienti riconosciuti, senza duplicati.
%
%   [ingredienti, punteggi] = ANALIZZA_IMMAGINI(immagini, sogliaPunteggio)
%   usa una soglia diversa da quella predefinita e restituisce anche il
%   punteggio di ciascun ingrediente.
%
%   Input:
%     immagini        - cell array di immagini ({img1, img2, ...}), una
%                       singola immagine, oppure string array / cell array
%                       di percorsi di file (["a.jpg", "b.jpg"])
%     sogliaPunteggio - punteggio minimo perché una predizione venga
%                       accettata (predefinito 0.4)
%
%   Output:
%     ingredienti - string array colonna, senza duplicati, nell'ordine in
%                   cui gli ingredienti compaiono nelle foto
%     punteggi    - punteggio di ciascun ingrediente (il più alto tra le
%                   foto in cui compare)
%
%   Nota sulla confidenza: il classificatore è un ECOC one-vs-all con SVM
%   lineari, quindi non fornisce probabilità. Come misura di confidenza si
%   usa il punteggio SVM del learner della classe predetta: un valore
%   maggiore di 0 indica che il learner riconosce la classe, valori più
%   alti indicano una decisione più netta. Non è una percentuale: la soglia
%   va tarata sulle foto reali.

    arguments
        immagini
        sogliaPunteggio (1,1) double = 0.4
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
    ingredienti = strings(0, 1);
    punteggi = zeros(0, 1);

    for i = 1:numel(immagini)
        img = immagini{i};

        % Se l'elemento è il percorso di un file, legge l'immagine
        if ischar(img) || isstring(img)
            img = imread(img);
        end

        % Preprocessing coerente con l'addestramento
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

        nome = string(label);
        punteggio = pbScore(classi == nome);

        if punteggio < sogliaPunteggio
            continue;
        end

        % Evita i duplicati: se l'ingrediente compare in più foto tiene
        % il punteggio più alto
        idx = find(ingredienti == nome, 1);
        if isempty(idx)
            ingredienti(end+1, 1) = nome; %#ok<AGROW>
            punteggi(end+1, 1) = punteggio; %#ok<AGROW>
        else
            punteggi(idx) = max(punteggi(idx), punteggio);
        end
    end
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
