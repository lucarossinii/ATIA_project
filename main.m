% MAIN Punto di ingresso dell'applicazione ATIA.
% Carica la configurazione dal file .env e avvia l'interfaccia grafica.
% Tutta la logica (stream, scatti, analisi e ricetta) è gestita dai
% callback della GUI in ATIA.mlapp.

clc;
clear;

% Cartella del progetto (quella che contiene questo script): così il
% programma funziona qualunque sia la cartella corrente di MATLAB
cartellaProgetto = fileparts(mfilename("fullpath"));
addpath(cartellaProgetto);

% Carica le variabili d'ambiente (API_KEY, CAMERA_URL, ...)
fileEnv = fullfile(cartellaProgetto, ".env");
if ~isfile(fileEnv)
    error("File .env non trovato in %s: crealo partendo da .env.example.", cartellaProgetto);
end
loadenv(fileEnv);

% Avvia l'interfaccia grafica
app = ATIA;

% Attende la chiusura della finestra; nel frattempo MATLAB continua a
% gestire i clic sui pulsanti
waitfor(app.UIFigure);

disp("Applicazione terminata.");
