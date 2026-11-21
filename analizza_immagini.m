function ingredientiRiconosciuti = analizza_immagini(immagini)
% ANALIZZA_IMMAGINI Classifica un array di immagini di lunghezza variabile
% mantenendo solo le predizioni con confidenza >= 70%.
%
% Input:
%   immagini - Cell array di immagini RGB ({img1, img2, ...}) oppure
%              string array / cell array di percorsi file (["a.jpg", "b.jpg"])
%
% Output:
%   ingredientiRiconosciuti - String array con le etichette che superano il 70%

    sogliaMinima = 40; % Soglia fissa al 70%

    % Carica rete e modello una sola volta in memoria tra chiamate successive
    persistent net modello
    if isempty(net) || isempty(modello)
        net = resnet50();
        modello = load('modello_resnet50_56classi2.mat', 'classifier', 'featureLayer', 'imagesize');
    end

    % Uniforma l'input in un cell array se viene passato un string array di percorsi
    if isstring(immagini) || ischar(immagini)
        immagini = cellstr(immagini);
    end

    numFoto = numel(immagini);
    ingredientiRiconosciuti = strings(0, 1); % Array di stringhe vuoto iniziale

    for i = 1:numFoto
        item = immagini{i};
        
        % Se l'elemento è il percorso di un file, leggi l'immagine; altrimenti usala direttamente
        if ischar(item) || isstring(item)
            img = imread(item);
        else
            img = item;
        end

        % Preprocessing coerente con l'allenamento
        ds = augmentedImageDatastore(modello.imagesize, img, ...
            'ColorPreprocessing', 'gray2rgb');

        % Estrazione features
        features = activations(net, ds, modello.featureLayer, ...
            'MiniBatchSize', 1, 'OutputAs', 'columns');

        % Predizione con probabilità posteriori
        [label, ~, posterior] = predict(modello.classifier, features, ...
            'ObservationsIn', 'columns');

        % Calcola la confidenza massima in percentuale (0 - 100%)
        confidenza = max(posterior) * 100;

        % Aggiunge l'ingrediente all'array solo se raggiunge almeno il 70%
        if confidenza >= sogliaMinima
            ingredientiRiconosciuti(end+1, 1) = string(label);
        end
    end
end