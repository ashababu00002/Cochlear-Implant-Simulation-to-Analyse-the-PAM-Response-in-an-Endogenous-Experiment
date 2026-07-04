clc
clear all
close all
[inputSignal, Fs] = audioread('16,250,8kUK university.wav');
targetFs = 44100; 

if Fs ~= targetFs
    inputSignal = resample(inputSignal, targetFs, Fs);
    Fs = targetFs;
end

loudness = integratedLoudness(inputSignal, Fs)
targetL = -35; % LUFS

gainDB = targetL - loudness;
gainLin = 10^(gainDB/20);
y = inputSignal * gainLin;


loudness2 = integratedLoudness(y, Fs)

numSamples = min(length(y), 10*Fs);

segment = y(1 : numSamples);

t = (0:(numSamples-1)) / Fs;


figure;
plot(t, segment);
xlabel('Time [s]');
ylabel('Amplitude');
title('First 10 seconds of audio');
xlim([0, min(10, length(y)/Fs)]);

y = y(100:end);

numSamples = min(length(y), 10*Fs);

segment = y(1 : numSamples);

t = (0:(numSamples-1)) / Fs;
figure;
plot(t, segment);
xlabel('Time [s]');
ylabel('Amplitude');
title('First 10 seconds of audio');

%%

trigger = repmat([ones(round(Fs*100e-6),1); zeros(round(Fs*100e-6),1)], 10, 1);

y_stereo = [y, [trigger; zeros(length(y)-2*length(trigger), 1); trigger]];

audiowrite('16,250,8kUK university_wt.wav', y_stereo, Fs);

figure;
subplot(2,1,1); plot(y_stereo(:,1)); title('Channel 1 - Main Audio');
subplot(2,1,2); plot(y_stereo(:,2)); title('Channel 2 - Trigger');

