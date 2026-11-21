function generaRicetta = genera_ricetta(ingredienti, creativita)
    % Inizializza l'output per evitare errori se la chiamata fallisce
    generaRicetta = "";

    % Imposta un valore predefinito se 'creativita' non viene passata
    if nargin < 2
        creativita = 0.7;
    end

    % 1. Endpoint e chiave API
    url = "https://api.openai.com/v1/chat/completions";
    apiKey = getenv("OPENAI_API_KEY");
    if apiKey == ""
        error("Chiave API mancante. Imposta la variabile d'ambiente OPENAI_API_KEY.");
    end

    % 2. Configurazione delle opzioni HTTP
    options = weboptions( ...
        "MediaType", "application/json", ...
        "HeaderFields", ["Authorization", "Bearer " + apiKey], ...
        "Timeout", 60 ...
    );

    % 3. Converte 'ingredienti' (char, string o array) in un'unica stringa
    listaIngredienti = strjoin(string(ingredienti), ", ");

    % 4. Costruzione del payload JSON
    payload = struct();
    payload.model = "gpt-4o-mini";
    payload.temperature = creativita;
    payload.messages = { ...
        struct("role", "system", "content", "Rispondi in modo conciso."), ...
        struct("role", "user", "content", "Genera una ricetta con i seguenti ingredienti: " + listaIngredienti) ...
    };

    % 5. Invio della chiamata POST ed estrazione del testo
    try
        response = webwrite(url, payload, options);
        generaRicetta = string(response.choices(1).message.content);
    catch ME
        fprintf("Errore durante la chiamata API: %s\n", ME.message);
    end
end