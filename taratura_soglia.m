function risultati = taratura_soglia(cartellaFoto, opzioni)
% TARATURA_SOGLIA Sceglie la soglia di confidenza di analizza_immagini.
%
%   TARATURA_SOGLIA(cartellaFoto) classifica le foto di prova contenute in
%   cartellaFoto, organizzate con una sottocartella per ingrediente con lo
%   stesso nome della classe del modello:
%
%       cartellaFoto/
%       ├── pomodoro/  foto1.jpg, foto2.jpg, ...
%       ├── mela/      ...
%       └── ...
%
%   e mostra nella Command Window:
%     - la percentuale di foto classificate correttamente, con l'immagine
%       intera e con il ritaglio centrale (opzione RitaglioCentrale di
%       analizza_immagini);
%     - per diverse soglie del margine, quante foto corrette vengono
%       accettate e quante sbagliate passano comunque;
%     - le confusioni più frequenti tra ingredienti;
%     - la soglia consigliata: la più bassa con cui, tra le foto accettate,
%       quelle sbagliate non superano QuotaErrori.
%
%   Usa foto scattate con la fotocamera dell'app, nelle condizioni reali
%   (luce, distanza, sfondo), e non usate per l'addestramento: sulle foto
%   di addestramento il modello sbaglia molto meno e la soglia risulterebbe
%   troppo bassa. Più foto ci sono per ingrediente, più la soglia è
%   affidabile.
%
%   risultati = TARATURA_SOGLIA(cartellaFoto, QuotaErrori=0.1) restituisce
%   anche una struct con i dettagli di ogni foto e la tabella delle soglie.
%
%   Opzioni:
%     QuotaErrori - quota massima di foto sbagliate tra quelle accettate
%                   (predefinita 0.1, cioè 10%)

    arguments
        cartellaFoto (1,1) string {mustBeFolder}
        opzioni.QuotaErrori (1,1) double {mustBeInRange(opzioni.QuotaErrori, 0, 1)} = 0.1
    end

    ds = imageDatastore(cartellaFoto, "IncludeSubfolders", true, ...
        "LabelSource", "foldernames");
    foto = string(ds.Files);
    vere = string(ds.Labels);

    % Le cartelle devono avere il nome di una classe del modello
    [~, ~, ~, classiModello] = analizza_immagini({});
    sconosciute = setdiff(unique(vere), classiModello);
    if ~isempty(sconosciute)
        warning("taratura_soglia:classiSconosciute", ...
            "Queste cartelle non corrispondono a nessuna classe del " + ...
            "modello e vengono ignorate: %s", strjoin(sconosciute, ", "));
        tieni = ~ismember(vere, sconosciute);
        foto = foto(tieni);
        vere = vere(tieni);
    end
    if isempty(foto)
        error("taratura_soglia:nessunaFoto", ...
            "Nessuna foto utilizzabile in %s.", cartellaFoto);
    end

    fprintf("Classificazione di %d foto di %d ingredienti...\n", ...
        numel(foto), numel(unique(vere)));

    % Soglie disattivate: serve il risultato di ogni foto, anche incerto
    disattivate = {"SogliaMargine", -Inf, "SogliaPunteggio", -Inf, "Diagnostica", false};
    [~, ~, intera] = analizza_immagini(foto, disattivate{:});
    [~, ~, ritagliata] = analizza_immagini(foto, disattivate{:}, "RitaglioCentrale", true);

    accuratezzaIntera = mean(intera.Classe == vere);
    accuratezzaRitaglio = mean(ritagliata.Classe == vere);
    fprintf("\nFoto classificate correttamente:\n");
    fprintf("  immagine intera (RitaglioCentrale=false): %5.1f%%\n", 100 * accuratezzaIntera);
    fprintf("  ritaglio centrale (RitaglioCentrale=true): %5.1f%%\n", 100 * accuratezzaRitaglio);

    usaRitaglio = accuratezzaRitaglio > accuratezzaIntera;
    if usaRitaglio
        d = ritagliata;
    else
        d = intera;
    end
    d.File = foto;
    d.Vera = vere;
    d.Corretta = d.Classe == vere;
    fprintf("La taratura usa RitaglioCentrale=%s.\n", string(usaRitaglio));

    % Effetto di ogni possibile soglia: le statistiche cambiano solo in
    % corrispondenza dei margini delle foto
    soglie = unique([0; d.Margine]);
    tabella = valutaSoglie(soglie, d);

    % Soglia consigliata: la più bassa che rispetta la quota di errori
    valide = tabella.Accettate > 0 & tabella.QuotaErrori <= opzioni.QuotaErrori;
    if any(valide)
        consigliata = tabella.SogliaMargine(find(valide, 1));
    else
        consigliata = NaN;
    end

    stampaTabella(d, opzioni.QuotaErrori);
    stampaConfusioni(d);

    fprintf("\n");
    if isnan(consigliata)
        fprintf("Nessuna soglia mantiene gli errori sotto il %.0f%%: il " + ...
            "modello sbaglia troppo su queste foto, va migliorato " + ...
            "l'addestramento.\n", 100 * opzioni.QuotaErrori);
    else
        r = tabella(find(valide, 1), :);
        fprintf("Soglia consigliata: SogliaMargine = %.2f\n", consigliata);
        fprintf("  accetta %d foto corrette su %d (%.0f%%), con %d sbagliate " + ...
            "tra le accettate (%.0f%%).\n", r.CorretteAccettate, sum(d.Corretta), ...
            100 * r.CorretteAccettate / max(sum(d.Corretta), 1), ...
            r.SbagliateAccettate, 100 * r.QuotaErrori);
        fprintf("Per usarla nell'app, in analizza_immagini.m imposta i " + ...
            "valori predefiniti SogliaMargine = %.2f e RitaglioCentrale = %s.\n", ...
            consigliata, string(usaRitaglio));
    end

    risultati = struct("Dettagli", d, "Soglie", tabella, ...
        "SogliaConsigliata", consigliata, "RitaglioCentrale", usaRitaglio, ...
        "AccuratezzaIntera", accuratezzaIntera, ...
        "AccuratezzaRitaglio", accuratezzaRitaglio);
end

function tabella = valutaSoglie(soglie, d)
% Per ogni soglia conta le foto accettate, corrette e sbagliate
    n = numel(soglie);
    accettate = zeros(n, 1);
    corrette = zeros(n, 1);
    for k = 1:n
        acc = d.Margine >= soglie(k);
        accettate(k) = sum(acc);
        corrette(k) = sum(acc & d.Corretta);
    end
    sbagliate = accettate - corrette;
    quota = sbagliate ./ max(accettate, 1);
    tabella = table(soglie, accettate, corrette, sbagliate, quota, ...
        'VariableNames', ["SogliaMargine", "Accettate", ...
        "CorretteAccettate", "SbagliateAccettate", "QuotaErrori"]);
end

function stampaTabella(d, quotaErrori)
% Stampa l'effetto di una griglia di soglie, al massimo 20 righe
    passo = max(0.05, ceil(max(d.Margine) / 20 / 0.05) * 0.05);
    griglia = (0:passo:max(d.Margine) + passo)';
    t = valutaSoglie(griglia, d);
    totCorrette = max(sum(d.Corretta), 1);

    entroObiettivo = t.Accettate > 0 & t.QuotaErrori <= quotaErrori;
    primaValida = find(entroObiettivo, 1);

    fprintf("\n%8s | %25s | %20s | %s\n", "Soglia", "Corrette accettate", ...
        "Sbagliate accettate", "Errori tra le accettate");
    for k = 1:height(t)
        segno = "";
        if k == primaValida
            segno = "  <- prima soglia entro l'obiettivo";
        end
        fprintf("%8.2f | %10d su %3d (%3.0f%%) | %20d | %5.0f%%%s\n", ...
            t.SogliaMargine(k), t.CorretteAccettate(k), sum(d.Corretta), ...
            100 * t.CorretteAccettate(k) / totCorrette, ...
            t.SbagliateAccettate(k), 100 * t.QuotaErrori(k), segno);
    end
end

function stampaConfusioni(d)
% Stampa le coppie di ingredienti confuse più spesso
    sbagliate = d(~d.Corretta, :);
    if isempty(sbagliate)
        fprintf("\nNessuna foto classificata in modo sbagliato.\n");
        return;
    end

    coppie = sbagliate.Vera + " scambiato per " + sbagliate.Classe;
    [nomi, ~, j] = unique(coppie);
    conteggi = accumarray(j, 1);
    [conteggi, ordine] = sort(conteggi, "descend");
    nomi = nomi(ordine);

    fprintf("\nConfusioni più frequenti:\n");
    for k = 1:min(10, numel(nomi))
        fprintf("  %3d x %s\n", conteggi(k), nomi(k));
    end
end
