function ricetta = genera_ricetta(ingredienti, creativita)
% GENERA_RICETTA Chiede a Google Gemini una ricetta con gli ingredienti dati.
%
%   ricetta = GENERA_RICETTA(ingredienti) restituisce il testo della
%   ricetta come stringa.
%
%   ricetta = GENERA_RICETTA(ingredienti, creativita) imposta la
%   temperatura del modello: 0 dà risposte prevedibili, 2 molto creative
%   (predefinito 0.7).
%
%   Richiede la variabile d'ambiente API_KEY (file .env). Il modello si
%   può cambiare con la variabile GEMINI_MODEL (predefinito
%   gemini-2.5-flash). Se qualcosa va storto lancia un errore con un
%   messaggio leggibile, che la GUI mostra all'utente.

    arguments
        ingredienti string
        creativita (1,1) double {mustBeInRange(creativita, 0, 2)} = 0.7
    end

    % Pulisce l'elenco degli ingredienti
    ingredienti = strtrim(ingredienti(:));
    ingredienti = ingredienti(strlength(ingredienti) > 0);
    if isempty(ingredienti)
        error("genera_ricetta:nessunIngrediente", ...
            "Nessun ingrediente fornito: impossibile generare una ricetta.");
    end

    % Chiave API e modello
    apiKey = string(getenv("API_KEY"));
    if strlength(apiKey) == 0
        error("genera_ricetta:chiaveMancante", ...
            "Chiave API mancante: imposta API_KEY nel file .env.");
    end

    modello = string(getenv("GEMINI_MODEL"));
    if strlength(modello) == 0
        modello = "gemini-2.5-flash";
    end
    url = "https://generativelanguage.googleapis.com/v1beta/models/" + modello + ":generateContent";

    % Opzioni HTTP (header richiesto da Gemini)
    options = weboptions( ...
        "MediaType", "application/json", ...
        "HeaderFields", ["x-goog-api-key", apiKey], ...
        "Timeout", 60);

    % Istruzioni di sistema e messaggio dell'utente
    istruzioni = join([
        "Sei un assistente di cucina. Rispondi sempre in italiano, in testo semplice,"
        "senza formattazione Markdown (niente asterischi, cancelletti o tabelle)."
        "Proponi una sola ricetta che usi gli ingredienti indicati; puoi aggiungere"
        "solo ingredienti di base da dispensa (sale, pepe, olio, acqua, burro, farina, zucchero)."
        "Struttura la risposta così: nome della ricetta, numero di persone,"
        "ingredienti con le quantità, procedimento in passi numerati, tempo totale."
        "Se un ingrediente non è adatto a una ricetta, ignoralo e segnalalo in una riga all'inizio."
        "Sii conciso."
        ], " ");

    sysInst = struct();
    sysInst.parts = { struct("text", istruzioni) };

    msgUtente = struct("role", "user");
    msgUtente.parts = { struct("text", "Ingredienti disponibili: " + strjoin(ingredienti, ", ")) };

    payload = struct();
    payload.system_instruction = sysInst;
    payload.contents = { msgUtente };
    payload.generationConfig = struct("temperature", creativita);

    % Invio della richiesta
    try
        risposta = webwrite(url, payload, options);
    catch ME
        error("genera_ricetta:richiestaFallita", ...
            "Richiesta all'API Gemini fallita: %s", ME.message);
    end

    ricetta = estraiTesto(risposta);
end

function testo = estraiTesto(risposta)
% Estrae il testo dalla risposta di Gemini unendo tutte le parti, esclusi
% gli eventuali blocchi di ragionamento del modello.

    if ~isfield(risposta, 'candidates') || isempty(risposta.candidates)
        motivo = "motivo sconosciuto";
        if isfield(risposta, 'promptFeedback') && isfield(risposta.promptFeedback, 'blockReason')
            motivo = "bloccata: " + string(risposta.promptFeedback.blockReason);
        end
        error("genera_ricetta:nessunaRisposta", ...
            "Gemini non ha restituito alcuna ricetta (%s).", motivo);
    end

    % jsondecode restituisce uno struct array se gli elementi hanno gli
    % stessi campi, altrimenti un cell array: gestisce entrambi i casi
    candidato = primoElemento(risposta.candidates);

    parti = {};
    if isfield(candidato, 'content') && isfield(candidato.content, 'parts')
        parti = candidato.content.parts;
        if isstruct(parti)
            parti = num2cell(parti);
        end
    end

    testo = "";
    for k = 1:numel(parti)
        parte = parti{k};
        if isfield(parte, 'thought') && isequal(parte.thought, true)
            continue;
        end
        if isfield(parte, 'text')
            testo = testo + string(parte.text);
        end
    end
    testo = strtrim(testo);

    if strlength(testo) == 0
        motivo = "motivo sconosciuto";
        if isfield(candidato, 'finishReason')
            motivo = string(candidato.finishReason);
        end
        error("genera_ricetta:rispostaVuota", ...
            "Gemini ha restituito una risposta vuota (%s).", motivo);
    end
end

function elem = primoElemento(lista)
    if iscell(lista)
        elem = lista{1};
    else
        elem = lista(1);
    end
end
