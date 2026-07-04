
% --- CONFIGURATION ---
inputWav     = '6,500,6kFood delivery app.wav';
outputWav    = '6,500,6kFood delivery app_withTrigger.wav';  % output file — pick a safe, unambiguous name
targetFs     = 44100;    % CD-compatible sampling rate
targetL      = -35;      % target loudness [LUFS]


% --- READ & RESAMPLE if needed ---
[x, Fs] = audioread(inputWav);
if Fs ~= targetFs
    x = resample(x, targetFs, Fs);
    Fs = targetFs;
end

numPulses   = 3;       % number of pulses at start and at end
pulseDur_us = 100;     % pulse duration in microseconds
pulseDur_s  = pulseDur_us * 1e-6;   % seconds
triggerAmp = 0.5;      % amplitude of trigger pulses (e.g. between -1 and +1)


% If stereo → make mono
if size(x,2) > 1
    x = mean(x, 2);
end

N = length(x);
% --- LOUDNESS NORMALIZATION ---
loudness = integratedLoudness(x, Fs)
gainDB = targetL - loudness;
gainLin = 10^(gainDB/20);
x = x * gainLin;  % scaled signal

% --- COMPUTE SAMPLES FOR PULSE ---
pulseSamples = round(pulseDur_s * Fs);
if pulseSamples < 1
    error('pulse duration too short for this sampling rate — results in 0 samples');
end

% --- PREPARE OUTPUT LENGTH: audio + pulses at start and end ---
outLen = N + numPulses * pulseSamples * 2;  % space for pulses
audioOut   = zeros(outLen, 1);
triggerOut = zeros(outLen, 1);

% --- INSERT AUDIO starting after start-pulses ---
audioOut( numPulses*pulseSamples + (1:N) ) = x;

% --- ADD start pulses ---
for p = 0:(numPulses-1)
    idx0 = p*pulseSamples + 1;
    idx1 = idx0 + pulseSamples - 1;
    triggerOut(idx0:idx1) = triggerAmp;
end

% --- ADD end pulses after audio ---
audioEnd = numPulses*pulseSamples + N;
for p = 0:(numPulses-1)
    idx0 = audioEnd + p*pulseSamples + 1;
    idx1 = min(idx0 + pulseSamples - 1, outLen);
    triggerOut(idx0:idx1) = triggerAmp;
end

% --- Combine stereo (audio + trigger) ---
y = [audioOut, triggerOut];

% --- Optionally normalize to avoid clipping ---
maxVal = max(abs(y), [], 'all');
if maxVal > 1
    y = y / maxVal * 0.99;
end

% --- WRITE WAV ---
audiowrite(outputWav, y, Fs);
fprintf('Wrote file "%s" (%.2f s) at %d Hz\n', outputWav, size(y,1)/Fs, Fs);


% --- PLOT signals ---
t = length(y);

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
