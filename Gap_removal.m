clc;
clear all;
close all;
[y, Fs] = audioread('Food delivery app.mp3');%load and read the mp3 file
size(y);

inputSignal = y(floor(150*Fs)+1:end, :);



if size(inputSignal,2) > 1
    monoSignal = mean(inputSignal, 2);
else
    monoSignal = inputSignal;
end


% Rectification
rectified = abs(monoSignal);

% Smoothing with moving average/ envolope extraction
window_ms = 100; 
window_samples = round(window_ms * 1e-3 * Fs);

kernel = ones(window_samples, 1) / window_samples;

smoothed = conv(rectified, kernel, 'same');

%thresholing speech / pause detection
threshold = 0.001;
isSpeech = (smoothed >= threshold);  % isSpeech is a logical vector (1 = speech, 0 = pause)

% To avoid cutting edges (morphological dialation)
buffer_ms = 10;
buffer_samps = round(buffer_ms * 1e-3 * Fs);
isSpeech = imdilate(isSpeech, true(buffer_samps*2+1, 1));

%Combining segments
d = diff([0; isSpeech; 0]);  
speech_starts = find(d == +1);
speech_ends   = find(d == -1) - 1;% d == +1 indicates start of speech; d == –1 indicates end

outputSignal = [];  

for k = 1:numel(speech_starts)
    s = speech_starts(k);
    e = speech_ends(k);

    outputSignal = [outputSignal; inputSignal(s:e, :)];% extract from original multichannel (keep all channels)
end



%%

durationSec = 300;   
numSamples = durationSec * Fs;
N = size(outputSignal, 1);

if N >= numSamples
    outAudio = inputSignal(1:numSamples, :); 
else
    warning('Input audio is shorter than 1 minute. Returning full audio.');
    outAudio = inputSignal;
end

audiowrite('Food delivery app.wav', outAudio, Fs);



durationSec = 60;   
numSamples = durationSec * Fs;
N = size(outAudio, 1);

if N >= numSamples
    outAudio_1 = inputSignal(1:numSamples, :); 
else
    warning('Input audio is shorter than 1 minute. Returning full audio.');
    outAudio_1 = inputSignal;
end



%%

clickVolume = 0.5;                         % How loud the clicks are (0.1 = quiet, 0.8 = loud)
silenceGap = 0.5;                          % 0.5 seconds of silence between click and audio

[numSamples, numChannels] = size(outAudio_1);


clickDuration = 0.1;                        % 100 milliseconds total
clickSamples = round(clickDuration * Fs);
gapSamples = round(silenceGap * Fs);        % Samples for the new silence gap

% sharp click
click1Samples = round(0.015 * Fs);          % 15ms
click1 = clickVolume * randn(click1Samples, 1);
envelope1 = exp(-100*(0:click1Samples-1)'/click1Samples);
click1 = click1 .* envelope1;


ClickGapSamples = round(0.02 * Fs);         % 20ms gap

% softer click
click2Samples = round(0.012 * Fs);          % 12ms
click2 = clickVolume * 0.7 * randn(click2Samples, 1);
envelope2 = exp(-120*(0:click2Samples-1)'/click2Samples);
click2 = click2 .* envelope2;

% Combine 
doubleClick = zeros(clickSamples, 1);
doubleClick(1:click1Samples) = click1;
startPos2 = click1Samples + ClickGapSamples;
if startPos2 + click2Samples <= clickSamples
   doubleClick(startPos2:startPos2+click2Samples-1) = click2;
end

segmentDuration = clickSamples + gapSamples;

% [CLICK] + [SILENCE GAP] + [AUDIO] + [SILENCE GAP] + [CLICK]

% Pad audio with silence gaps at start and end
paddedAudio = [zeros(gapSamples, numChannels); outAudio_1; zeros(gapSamples, numChannels)];

% Add the click segments at the very start and very end
output = [zeros(clickSamples, numChannels); paddedAudio; zeros(clickSamples, numChannels)];

% Add trigger channel
output = [output, zeros(size(output,1), 1)]; % Add trigger channel
totalSamples = size(output, 1);

start_click_end = clickSamples;              % Position after the first click
for ch = 1:numChannels
    output(1:start_click_end, ch) = doubleClick;
end
output(1:start_click_end, end) = 1;          % Trigger pulse at start

end_click_start = totalSamples - clickSamples + 1; % Start position of the last click
for ch = 1:numChannels 
    output(end_click_start:end, ch) = doubleClick;
end

output(end_click_start:end, end) = 1;     % Trigger pulse at end

% Preventing distortion 
if max(abs(output(:))) > 1
   output = output / max(abs(output(:)));
end

audiowrite('Food delivery app_1mint.wav', output, Fs);



