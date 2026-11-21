
clc;
clear;

% Carica le variabili d'ambiente
loadenv(".env");

% Avvia l'interfaccia grafica
app = ATIA;

% Verifica che l'applicazione sia valida
if isempty(app) || ~isvalid(app)
    warning("Impossibile avviare l'applicazione.");
    return;
end

% Ciclo principale
while isvalid(app)

    try

        if app.GeneraPremuto
            
            % Resetta la variabile che stabilisce se il tasto genera è
            % stato premuto
            app.GeneraPremuto = false;

            
            % Chiamata alla funzione che analizza le immagini per estrarre
            % gli ingredienti
            ingredienti = analizza_immagini(app.CapturedImages);


            % Chiamata alla funzione che genera la ricetta
            ricetta = genera_ricetta(ingredienti, 1);

             % Scrive la ricetta nell'area di testo
            if strlength(string(ricetta)) == 0
                warning("Impossibile generare una ricetta.");
            else
                app.ricettaTextArea.Value = char(ricetta);
            end

            % Forza la scrittura immediata
            drawnow;
           
        end

        catch ME
        warning(E.ME, "Errore durante l'aborazione:" +'%s', ME.message);
        if isvalid(app)
            app.ricettaTextArea.Value = "Errore: " + ME.message;
        end

    % Cede il controllo alla GUI per intercettare i clic sui pulsanti
    drawnow;
    pause(0.1);

    end

end

disp("Applicazione terminata.");
