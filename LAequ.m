clc
clear all
close all

[inputSignal, Fs] = audioread('16,250,8kMinimum wage_wt.wav');

target_dB         = 50;
measured_dB       = 57.1;
gain_dB           = target_dB - measured_dB;

factor            = 10^(gain_dB/20);
 
actual_dB         = factor*inputSignal;

actual_dB         = max(min(actual_dB, 1), -1);


audiowrite('16,250,8kMinimum wage.wav',actual_dB, Fs);



