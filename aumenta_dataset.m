function riepilogo = aumenta_dataset(cartellaInput, cartellaOutput, opzioni)
% AUMENTA_DATASET Crea una versione aumentata e bilanciata del dataset.
%
%   AUMENTA_DATASET(cartellaInput, cartellaOutput) legge il dataset in
%   cartellaInput, organizzato con una sottocartella per classe:
%
%       cartellaInput/
%       ├── mela/      img1.jpg, img2.jpg, ...
%       ├── pomodoro/  ...
%       └── ...
%
%   e scrive in cartellaOutput la stessa struttura con le immagini
%   originali più quelle aumentate, finché ogni classe raggiunge lo stesso
%   numero di immagini (predefinito: quello della classe più numerosa).
%   Il dataset originale non viene modificato.
%
%   riepilogo = AUMENTA_DATASET(..., Nome=Valore) accetta le opzioni:
%     ImmaginiPerClasse - numero di immagini da raggiungere per ogni
%                         classe (predefinito: quello della classe più
%                         numerosa). Le classi che lo superano già vengono
%                         solo copiate.
%     Moltiplicatore    - in alternativa, porta ogni classe ad almeno
%                         Moltiplicatore volte le sue immagini originali
%                         (predefinito 1, cioè solo bilanciamento). Vale
%                         il valore più alto tra i due criteri.
%     Intensita         - scala l'ampiezza di tutte le trasformazioni
%                         (predefinito 1; 0.5 più delicate, 1.5 più forti)
%     Seme              - seme del generatore casuale, per risultati
%                         riproducibili (predefinito 42)
%     Anteprima         - se true salva in cartellaOutput un'immagine con
%                         alcuni esempi originali e aumentati
%                         (predefinito true)
%
%   Output:
%     riepilogo - tabella con, per ogni classe, il numero di immagini
%                 originali, quelle generate e il totale
%
%   Le trasformazioni simulano le variazioni delle foto reali scattate con
%   la fotocamera dell'app:
%     - geometriche: rotazione, ribaltamento orizzontale, zoom,
%       spostamento e ritaglio casuale
%     - colore: luminosità, contrasto, saturazione, gamma e una piccola
%       variazione di tinta (piccola per non cambiare l'ingrediente, ad
%       esempio un pomodoro rosso in uno arancione)
%     - qualità: rumore, leggera sfocatura e compressione JPEG
%
%   Usa solo funzioni di MATLAB base: non richiede toolbox.
%
%   Esempio:
%     aumenta_dataset("dataset", "dataset_aumentato", ImmaginiPerClasse=300)

    arguments
        cartellaInput (1,1) string
        cartellaOutput (1,1) string
        opzioni.ImmaginiPerClasse double {mustBeScalarOrEmpty, mustBeInteger, mustBePositive} = []
        opzioni.Moltiplicatore (1,1) double {mustBePositive} = 1
        opzioni.Intensita (1,1) double {mustBeNonnegative} = 1
        opzioni.Seme (1,1) double = 42
        opzioni.Anteprima (1,1) logical = true
    end

    verificaCartelle(cartellaInput, cartellaOutput);
    rng(opzioni.Seme);

    % Legge il dataset: l'etichetta di ogni immagine è il nome della sua
    % sottocartella
    ds = imageDatastore(cartellaInput, "IncludeSubfolders", true, ...
        "LabelSource", "foldernames");
    if isempty(ds.Files)
        error("aumenta_dataset:datasetVuoto", ...
            "Nessuna immagine trovata in %s.", cartellaInput);
    end

    conteggi = countEachLabel(ds);
    classi = string(conteggi.Label);
    originali = conteggi.Count;

    obiettivo = opzioni.ImmaginiPerClasse;
    if isempty(obiettivo)
        obiettivo = max(originali);
    end

    fprintf("Dataset: %d immagini in %d classi (min %d, max %d per classe).\n", ...
        sum(originali), numel(classi), min(originali), max(originali));

    generate = zeros(numel(classi), 1);
    esempi = cell(0, 3);  % {classe, originale, aumentata} per l'anteprima

    for c = 1:numel(classi)
        fileClasse = string(ds.Files(ds.Labels == classi(c)));
        cartellaClasse = fullfile(cartellaOutput, classi(c));
        mkdir(cartellaClasse);

        % Copia le immagini originali
        for f = 1:numel(fileClasse)
            copyfile(fileClasse(f), cartellaClasse);
        end

        % Immagini da generare per raggiungere l'obiettivo
        totale = max(obiettivo, ceil(opzioni.Moltiplicatore * originali(c)));
        daGenerare = max(totale - originali(c), 0);

        % Ogni originale viene usata a turno, in ordine casuale, così le
        % immagini aumentate sono distribuite in modo uniforme
        ordine = [];
        for k = 1:daGenerare
            if isempty(ordine)
                ordine = randperm(numel(fileClasse));
            end
            sorgente = fileClasse(ordine(1));
            ordine(1) = [];

            img = leggiRGB(sorgente);
            aumentata = trasforma(img, opzioni.Intensita);

            [~, nomeBase] = fileparts(sorgente);
            nomeFile = fullfile(cartellaClasse, ...
                sprintf("%s_aug%04d.jpg", nomeBase, k));
            imwrite(aumentata, nomeFile, "Quality", 95);

            % Un esempio per classe, per le prime classi
            if k == 1 && size(esempi, 1) < 8
                esempi(end+1, :) = {classi(c), img, aumentata}; %#ok<AGROW>
            end
        end

        generate(c) = daGenerare;
        fprintf("[%2d/%d] %-25s %5d originali + %5d generate = %5d\n", ...
            c, numel(classi), classi(c), originali(c), daGenerare, ...
            originali(c) + daGenerare);
    end

    riepilogo = table(classi, originali, generate, originali + generate, ...
        'VariableNames', ["Classe", "Originali", "Generate", "Totale"]);
    writetable(riepilogo, fullfile(cartellaOutput, "riepilogo_aumento.csv"));

    fprintf("Completato: %d immagini generate, %d in totale in %s.\n", ...
        sum(generate), sum(riepilogo.Totale), cartellaOutput);

    if opzioni.Anteprima && ~isempty(esempi)
        salvaAnteprima(esempi, fullfile(cartellaOutput, "anteprima_aumento.png"));
    end
end

function verificaCartelle(cartellaInput, cartellaOutput)
% Controlla che l'input esista e che l'output non rischi di mescolarsi
% con altri dati
    if ~isfolder(cartellaInput)
        error("aumenta_dataset:inputMancante", ...
            "La cartella %s non esiste.", cartellaInput);
    end

    input = string(java.io.File(cartellaInput).getCanonicalPath());
    output = string(java.io.File(cartellaOutput).getCanonicalPath());
    if input == output || startsWith(output, input + filesep)
        error("aumenta_dataset:outputNonValido", ...
            "La cartella di output non può coincidere con quella del " + ...
            "dataset né trovarsi al suo interno.");
    end

    if isfolder(cartellaOutput) && numel(dir(cartellaOutput)) > 2
        error("aumenta_dataset:outputNonVuoto", ...
            "La cartella %s esiste già e non è vuota: scegline un'altra " + ...
            "o svuotala.", cartellaOutput);
    end
end

function img = leggiRGB(file)
% Legge un'immagine e la converte in RGB double in [0, 1]
    [img, mappa] = imread(file);
    if ~isempty(mappa)
        img = ind2rgb(img, mappa);
    end
    img = im2double(img);
    if size(img, 3) == 1
        img = repmat(img, 1, 1, 3);
    elseif size(img, 3) > 3
        img = img(:, :, 1:3);  % scarta il canale alfa o CMYK extra
    end
end

function img = trasforma(img, s)
% Applica una sequenza casuale di trasformazioni con intensità s
    img = trasformaGeometrica(img, s);
    img = ritaglioCasuale(img, 1 - 0.2 * s);
    img = trasformaColore(img, s);
    img = degradaQualita(img, s);
    img = min(max(img, 0), 1);
end

function out = trasformaGeometrica(img, s)
% Rotazione, ribaltamento, zoom e spostamento in un'unica trasformazione
% affine. I pixel fuori dall'immagine replicano il bordo, così non
% compaiono angoli neri.
    [h, w, ~] = size(img);

    angolo = deg2rad(casuale(-20, 20) * s);
    zoom = 1 + casuale(-0.2, 0.2) * s;
    spostamento = [casuale(-0.1, 0.1) * w, casuale(-0.1, 0.1) * h] * s;
    ribalta = rand < 0.5;

    % Per ogni pixel di output calcola la posizione di partenza
    % nell'immagine originale (trasformazione inversa)
    [x, y] = meshgrid(1:w, 1:h);
    cx = (w + 1) / 2;
    cy = (h + 1) / 2;
    xc = (x - cx - spostamento(1)) / zoom;
    yc = (y - cy - spostamento(2)) / zoom;
    xs = cos(angolo) * xc + sin(angolo) * yc;
    ys = -sin(angolo) * xc + cos(angolo) * yc;
    if ribalta
        xs = -xs;
    end
    xs = min(max(xs + cx, 1), w);
    ys = min(max(ys + cy, 1), h);

    out = zeros(size(img));
    for k = 1:3
        out(:, :, k) = interp2(img(:, :, k), xs, ys, "linear");
    end
end

function img = ritaglioCasuale(img, areaMinima)
% Ritaglia una porzione casuale che conserva almeno areaMinima dell'area
    areaMinima = min(max(areaMinima, 0.3), 1);
    [h, w, ~] = size(img);
    lato = sqrt(casuale(areaMinima, 1));
    nh = max(round(h * lato), 1);
    nw = max(round(w * lato), 1);
    r = randi(h - nh + 1);
    c = randi(w - nw + 1);
    img = img(r:r+nh-1, c:c+nw-1, :);
end

function img = trasformaColore(img, s)
% Luminosità, contrasto, saturazione, tinta e gamma
    img = img + casuale(-0.15, 0.15) * s;                          % luminosità
    media = mean(img, "all");
    img = (img - media) * (1 + casuale(-0.2, 0.2) * s) + media;    % contrasto
    img = min(max(img, 0), 1);

    hsv = rgb2hsv(img);
    hsv(:, :, 1) = mod(hsv(:, :, 1) + casuale(-0.02, 0.02) * s, 1); % tinta
    hsv(:, :, 2) = min(hsv(:, :, 2) * (1 + casuale(-0.25, 0.25) * s), 1); % saturazione
    img = hsv2rgb(hsv);

    img = img .^ (1 + casuale(-0.2, 0.2) * s);                     % gamma
end

function img = degradaQualita(img, s)
% Rumore, sfocatura e compressione JPEG, ognuno applicato solo a una parte
% delle immagini
    if s == 0
        return;
    end

    if rand < 0.3
        sigma = casuale(0.5, 1.5) * s;
        img = sfoca(img, sigma);
    end

    if rand < 0.3
        img = img + randn(size(img)) * casuale(0.005, 0.03) * s;
        img = min(max(img, 0), 1);
    end

    if rand < 0.5
        qualita = round(90 - casuale(0, 50) * min(s, 1));
        fileTemp = [tempname, '.jpg'];
        imwrite(img, fileTemp, "Quality", qualita);
        img = im2double(imread(fileTemp));
        delete(fileTemp);
    end
end

function img = sfoca(img, sigma)
% Sfocatura gaussiana separabile, con bordi replicati
    raggio = max(ceil(3 * sigma), 1);
    t = -raggio:raggio;
    kernel = exp(-t.^2 / (2 * sigma^2));
    kernel = kernel / sum(kernel);
    for k = 1:3
        canale = img(:, :, k);
        canale = [repmat(canale(:, 1), 1, raggio), canale, repmat(canale(:, end), 1, raggio)];
        canale = conv2(canale, kernel, "valid");
        canale = [repmat(canale(1, :), raggio, 1); canale; repmat(canale(end, :), raggio, 1)];
        img(:, :, k) = conv2(canale, kernel', "valid");
    end
end

function v = casuale(a, b)
% Numero casuale uniforme in [a, b]
    v = a + (b - a) * rand;
end

function salvaAnteprima(esempi, file)
% Salva una griglia con le immagini originali (sopra) e aumentate (sotto)
    n = size(esempi, 1);
    fig = figure("Visible", "off", "Position", [100 100 220 * n 480], "Color", "w");
    tiledlayout(fig, 2, n, "TileSpacing", "compact", "Padding", "compact");
    for i = 1:n
        nexttile(i);
        image(esempi{i, 2}); axis image off;
        title(esempi{i, 1} + " (originale)", "Color", "k", "Interpreter", "none");
        nexttile(n + i);
        image(esempi{i, 3}); axis image off;
        title("aumentata", "Color", "k");
    end
    exportgraphics(fig, file);
    close(fig);
end
