clc;
close all;
clear all;
T = readtable('Thesis_Data_Master.xlsx','sheet','Effort');
maxScale = 20;
rawScores = T{:, 2:end};
normalizedScores1 = (rawScores/ maxScale);
normalizedScores = (rawScores/ maxScale)*100;
avgEffort = mean(normalizedScores, 1, 'omitnan');
stdEffort = std(normalizedScores, 0, 1, 'omitnan');
conditions = T.Properties.VariableNames(2:end);

figure;
hold on;


b = bar(avgEffort, 'FaceColor', [0.2 0.6 0.8], 'EdgeColor', 'k');


errorbar(1:numel(avgEffort), avgEffort, stdEffort, 'k', 'linestyle', 'none', 'LineWidth', 1.5);


title('Effort (% of Max)', 'FontSize', 12);
ylabel('Effort (0 - 100%)');
xlabel('Conditions');
ylim([0 110]); 
set(gca, 'XTick', 1:numel(conditions), 'XTickLabel', conditions, 'XTickLabelRotation', 45);
grid on;
for i = 1:numel(avgEffort)
    text(i, avgEffort(i) + (stdEffort(i)*0.2) + 2, [num2str(avgEffort(i), '%.1f'), '%'], ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold');
end
hold off;

frontData = mean(normalizedScores(:, 1:4), 2);
backData  = mean(normalizedScores(:, 5:8), 2);
meanPos = [mean(frontData), mean(backData)];
stdPos  = [std(frontData), std(backData)];
easyData = mean(normalizedScores(:, [1, 2, 5, 6]), 2);
diffData = mean(normalizedScores(:, [3, 4, 7, 8]), 2);
meanDiff = [mean(easyData), mean(diffData)];
stdDiff  = [std(easyData), std(diffData)];

leftData = mean(normalizedScores(:, [1, 3, 5, 7]), 2);
rightData = mean(normalizedScores(:, [2, 4, 6, 8]), 2);
meanattend = [mean(leftData), mean(rightData)];
stdattend  = [std(leftData), std(rightData)];


finalFrontMean = mean(frontData);
finalBackMean  = mean(backData);
finalEasytMean = mean(easyData);
finaldiffMean  = mean(diffData);
finallefttMean = mean(leftData);
finalrightMean  = mean(rightData);


figure;
subplot(1,3,1); 
bar(meanPos, 'FaceColor', [0.2 0.4 0.6]); hold on;
errorbar(1:2, meanPos, stdPos, 'k', 'LineStyle', 'none');
set(gca, 'XTickLabel', {'Front', 'Back'});
title('Position: Front vs Back');
ylabel('Effort (%)');
ylim([0 110]);
for i = 1:2
    text(i, meanPos(i) + (stdPos(i) * 0.1) + 3, sprintf('%.1f%%', meanPos(i)), ...
         'HorizontalAlignment', 'center', 'FontWeight', 'bold');
end
subplot(1,3,2); 
bar(meanDiff, 'FaceColor', [0.6 0.2 0.2]); hold on;
errorbar(1:2, meanDiff, stdDiff, 'k', 'LineStyle', 'none');
set(gca, 'XTickLabel', {'Easy', 'Difficult'});
title('Task: Easy vs Difficult');
ylabel('Effort (%)');
ylim([0 110]);
for i = 1:2
    text(i, meanDiff(i) + (stdDiff(i) * 0.1) + 3, sprintf('%.1f%%', meanDiff(i)), ...
         'HorizontalAlignment', 'center', 'FontWeight', 'bold');
end

subplot(1,3,3); 
bar(meanattend, 'FaceColor', [0.6 0.2 0.2]); hold on;
errorbar(1:2, meanattend, stdattend, 'k', 'LineStyle', 'none');
set(gca, 'XTickLabel', {'Left', 'Right'});
title('Task: Left vs Right');
ylabel('Effort (%)');
ylim([0 110]);
for i = 1:2
    text(i, meanattend(i) + (stdattend(i) * 0.1) + 3, sprintf('%.1f%%', meanattend(i)), ...
         'HorizontalAlignment', 'center', 'FontWeight', 'bold');
end

