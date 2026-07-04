% Revised script: read audio → resample → loudness normalize → detect speech → build stereo (audio + trigger) → write WAV

clear all
close all
clc

% --- CONFIGURATION ---
inputWav     = '6,500,6kFood delivery app.wav';
outputWav    = '6,500,6kFood delivery app_withTrigger.wav';  % output file — pick a safe, unambiguous name
targetFs     = 44100;    % CD-compatible sampling rate
targetL      = -35;      % target loudness [LUFS]

preGapSec       = 2.0;    % 2-second silence before audio  
pulseDur        = 100;   % 50 ms pulses  
pulseInterval   = 0.2;    % 200 ms between start-of-speech pulses  
numPulsesStart  = 3;      % number of pulses at start  
finalPulseAfter = 0.0;    % seconds after end-of-speech for final pulse  

triggerAmp = 0.05;        % amplitude of trigger pulses — consider increasing from 0.01 for better detectability

% --- READ & (if needed) RESAMPLE ---
[x, Fs] = audioread(inputWav);
if Fs ~= targetFs
    x = resample(x, targetFs, Fs);
    Fs = targetFs;
end

% --- MIX / MAKE MONO if stereo (optional) ---
if size(x,2) > 1
    x = mean(x, 2);  % simple mono mix — or pick one channel if you prefer
end

% --- LOUDNESS NORMALIZATION ---
loudness = integratedLoudness(x, Fs)
gainDB = targetL - loudness;
gainLin = 10^(gainDB/20);
x = x * gainLin;  % scaled signal


if size(x,2) > 1
    inputMono = mean(x,2);
else
    inputMono = x;
end

% Use detectSpeech to find speech segments
[speechIdx, ~] = detectSpeech(inputMono, Fs);
if isempty(speechIdx)
    error('No speech detected');
end

% Determine first speech sample
firstSpeech = speechIdx(1,1);

% Trim: from first speech to end
output = inputMono(firstSpeech:end);

% Optionally write trimmed file
audiowrite('trimmed.wav', output, Fs);


% --- SPEECH DETECTION ON NORMALIZED AUDIO ---
[speechIdx, thresholds] = detectSpeech(x, Fs);
if isempty(speechIdx)
    error('No speech detected in the audio (after normalization).');
end
speechStart = speechIdx(1,1);
speechEnd   = speechIdx(end,2);

% --- PREPARE OUTPUT LENGTH & PULSE SIZES ---
preGapSamples   = round(preGapSec * Fs);
N               = length(x);
outLen          = preGapSamples + N;
pulseSamples    = round(pulseDur * Fs);
intervalSamples = round(pulseInterval * Fs);

% --- INITIALIZE OUTPUT CHANNELS ---
audioOut   = zeros(outLen, 1);
triggerOut = zeros(outLen, 1);

% INSERT AUDIO WITH PRE-GAP
audioOut(preGapSamples + (1:N)) = x;

% --- COMPUTE SPEECH START/END IN OUTPUT SPACE ---
speechStartOut = preGapSamples + speechStart;
speechEndOut   = preGapSamples + speechEnd;

% --- ADD START-OF-SPEECH PULSES ---
for p = 0:(numPulsesStart - 1)
    idx0 = speechStartOut + p * intervalSamples;
    idx1 = min(idx0 + pulseSamples - 1, outLen);
    triggerOut(idx0:idx1) = triggerAmp;
end

% --- OPTIONAL: final pulse after end-of-speech ---
final0 = speechEndOut + round(finalPulseAfter * Fs);
final1 = min(final0 + pulseSamples - 1, outLen);
triggerOut(final0:final1) = triggerAmp;

% --- COMBINE INTO 2-CHANNEL (stereo) SIGNAL ---
y = [audioOut, triggerOut];

% --- WRITE OUTPUT WAV ---
audiowrite(outputWav, y, Fs);

t = (0:(size(y,1)-1)) / Fs; 
figure;
subplot(2,1,1);
plot(t, y(:,1));
title('Audio signal');
xlabel('Time (s)');
ylabel('Amplitude');
xlim([0 t(end)]);

subplot(2,1,2);
plot(t, y(:,2));
title('Trigger channel');
xlabel('Time (s)');
ylabel('Amplitude');
xlim([0 t(end)]);


