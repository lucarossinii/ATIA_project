function generaRicetta = genera_ricetta(ingredienti, creativita)
    % Inizializza l'output per evitare errori se la chiamata fallisce
    generaRicetta = "";

    % Imposta un valore predefinito se 'creativita' non viene passata
    if nargin < 2
        creativita = 0.7;
    end

    % 1. Endpoint e chiave API
    modello = "gemini-2.5-flash";
    url = "https://generativelanguage.googleapis.com/v1beta/models/" + modello + ":generateContent";
    apiKey = getenv("API_KEY");
    if apiKey == ""
        error("Chiave API mancante. Imposta la variabile d'ambiente API_KEY nel file .env.");
    end

    % 2. Configurazione delle opzioni HTTP (header richiesto da Gemini)
    options = weboptions( ...
        "MediaType", "application/json", ...
        "HeaderFields", ["x-goog-api-key", apiKey], ...
        "Timeout", 60 ...
    );

    % 3. Converte 'ingredienti' (char, string o array) in un'unica stringa
    listaIngredienti = strjoin(string(ingredienti), ", ");

    % 4. Costruzione del payload JSON nel formato nativo di Gemini
    sysInst = struct();
    sysInst.parts = { struct("text", "Rispondi in modo conciso.") };

    msgUtente = struct("role", "user");
    msgUtente.parts = { struct("text", "Genera una ricetta con i seguenti ingredienti: " + listaIngredienti) };

    payload = struct();
    payload.system_instruction = sysInst;
    payload.contents = { msgUtente };
    payload.generationConfig = struct("temperature", creativita);

    % 5. Invio della chiamata POST ed estrazione del testo
    try
        response = webwrite(url, payload, options);
        parts = response.candidates(1).content.parts;
        
        % Gestisce sia array di struct sia cell array (es. se il modello include blocchi di thinking)
        if iscell(parts)
            generaRicetta = string(parts{end}.text);
        else
            generaRicetta = string(parts(end).text);
        end
    catch ME
        fprintf("Errore durante la chiamata API: %s\n", ME.message);
    end
end