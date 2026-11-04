clear;
clc;
close all;


Fs = 5000;

highPassFreq = 20;
lowPassFreq = 450;
filterOrder = 4;

rmsWindow_ms = 50;

featureWindow_ms = 50;

initialRest = [0 2.7];
relaxationPeriod = [5.0 6.7];


ON_margin = 15;       
OFF_margin = 10;      


minimumContraction_ms = 150;
maximumGap_ms = 400;   

% Zero crossing threshold
zcThreshold = 5;

filename = '04-11-26_NA_EMGSamples(Alex)2_V1.txt';

fid = fopen(filename,'r');

if fid == -1
    error('Could not open the EMG file.');
end

EMG = [];

while ~feof(fid)

    line = strtrim(fgetl(fid));

    if ~isempty(line) && ...
       ~isempty(regexp(line, ...
       '^[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?$', ...
       'once'))

        sample = str2double(line);

        if isfinite(sample)
            EMG(end+1,1) = sample;
        end

    end

end

fclose(fid);

if isempty(EMG)
    error('No numeric EMG samples found.');
end

N = length(EMG);

time = (0:N-1)'/Fs;

duration = N/Fs;

fprintf('Samples: %d\n',N);
fprintf('Duration: %.3f seconds\n',duration);


initialRestMask = time >= initialRest(1) & ...
                  time <= initialRest(2);

dcOffset_counts = median(EMG(initialRestMask));

EMG_zeroed = EMG - dcOffset_counts;

fprintf('Estimated DC offset: %.2f ADC counts\n', ...
    dcOffset_counts);


[b,a] = butter(filterOrder, ...
    [highPassFreq lowPassFreq]/(Fs/2), ...
    'bandpass');

filteredEMG = filtfilt(b,a,EMG_zeroed);


rmsWindow = round(rmsWindow_ms*Fs/1000);

rmsEnvelope = sqrt(movmean( ...
    filteredEMG.^2,rmsWindow));

restMask1 = time >= initialRest(1) & ...
            time <= initialRest(2);

restMask2 = time >= relaxationPeriod(1) & ...
            time <= relaxationPeriod(2);

restMask = restMask1 | restMask2;

relaxedRMS = rmsEnvelope(restMask);

relaxedRMS = relaxedRMS(isfinite(relaxedRMS));

rest95 = percentile_local(relaxedRMS,95);
rest99 = percentile_local(relaxedRMS,99);

restMedian = median(relaxedRMS);

onThreshold = rest99 + ON_margin;

offThreshold = rest95 + OFF_margin;

if offThreshold >= onThreshold
    offThreshold = onThreshold*0.8;
end

fprintf('\n========== THRESHOLDS ==========\n');
fprintf('Relaxed RMS median: %.2f\n',restMedian);
fprintf('Relaxed RMS 95th percentile: %.2f\n',rest95);
fprintf('Relaxed RMS 99th percentile: %.2f\n',rest99);
fprintf('ON threshold: %.2f\n',onThreshold);
fprintf('OFF threshold: %.2f\n',offThreshold);

minimumContraction = round( ...
    minimumContraction_ms*Fs/1000);

maximumGap = round(maximumGap_ms*Fs/1000);

active = false(N,1);

isActive = false;

belowOFFcount = 0;

for i = 1:N

    if ~isActive

        if rmsEnvelope(i) >= onThreshold

            isActive = true;
            belowOFFcount = 0;

        end

    else

        if rmsEnvelope(i) < offThreshold

            belowOFFcount = belowOFFcount + 1;

        else

            belowOFFcount = 0;

        end

        if belowOFFcount >= maximumGap

            isActive = false;
            belowOFFcount = 0;

        end

    end

    active(i) = isActive;

end


edges = diff([false;active;false]);

onsets = find(edges == 1);

offsets = find(edges == -1)-1;

for k = 1:length(onsets)

    activationLength = offsets(k)-onsets(k)+1;

    if activationLength < minimumContraction

        active(onsets(k):offsets(k)) = false;

    end

end

edges = diff([false;active;false]);

onsets = find(edges == 1);

offsets = find(edges == -1)-1;

numberOfContractions = length(onsets);

onsetTime = time(onsets);

offsetTime = time(offsets);

contractionDuration = (offsets-onsets+1)/Fs;


peakRMS = zeros(numberOfContractions,1);

meanRMS = zeros(numberOfContractions,1);

for k = 1:numberOfContractions

    segment = onsets(k):offsets(k);

    peakRMS(k) = max(rmsEnvelope(segment));

    meanRMS(k) = mean(rmsEnvelope(segment));

end


relaxationDuration = nan(numberOfContractions,1);

for k = 1:numberOfContractions-1

    relaxationDuration(k) = ...
        onsetTime(k+1)-offsetTime(k);

end


featureWindow = round(featureWindow_ms*Fs/1000);

numberOfWindows = floor(N/featureWindow);

RMS = nan(numberOfWindows,1);
MAV = nan(numberOfWindows,1);
ZC = nan(numberOfWindows,1);

featureTime = nan(numberOfWindows,1);

for k = 1:numberOfWindows

    idx = (k-1)*featureWindow+1:k*featureWindow;

    segment = filteredEMG(idx);

    % RMS
    RMS(k) = sqrt(mean(segment.^2));

    % MAV
    MAV(k) = mean(abs(segment));

    % Zero crossings
    crossings = ...
        (segment(1:end-1).*segment(2:end) < 0) & ...
        (abs(segment(1:end-1)-segment(2:end)) >= zcThreshold);

    ZC(k) = sum(crossings);

    featureTime(k) = mean(time(idx));

end


FeatureTable = table( ...
    featureTime,RMS,MAV,ZC, ...
    'VariableNames', ...
    {'Time_s','RMS','MAV','ZeroCrossings'});


ContractionTable = table( ...
    (1:numberOfContractions)', ...
    onsetTime, ...
    offsetTime, ...
    contractionDuration, ...
    relaxationDuration, ...
    peakRMS, ...
    meanRMS, ...
    'VariableNames', ...
    {'Contraction','Onset_s','Offset_s', ...
     'Duration_s','Relaxation_s', ...
     'PeakRMS','MeanRMS'});


figure('Name','Complete EMG Analysis', ...
       'Color','w', ...
       'Position',[100 100 1500 850]);

tiledlayout(2,2, ...
    'TileSpacing','compact', ...
    'Padding','compact');

ax1 = nexttile;

plot(time,EMG,'b','LineWidth',0.7);

title('Raw EMG');
xlabel('Time (s)');
ylabel('ADC Counts');

grid on;
box off;
xlim([0 duration]);


ax2 = nexttile;

plot(time,filteredEMG,'b','LineWidth',0.7);

title('Filtered EMG');
xlabel('Time (s)');
ylabel('ADC Counts');

grid on;
box off;
xlim([0 duration]);


ax3 = nexttile;
hold on;

activationYmax = max(rmsEnvelope)*1.15;

ylim([0 activationYmax]);

for k = 1:numberOfContractions

    patch(ax3, ...
        [onsetTime(k) offsetTime(k) ...
         offsetTime(k) onsetTime(k)], ...
        [0 0 activationYmax activationYmax], ...
        [0.75 0.9 0.75], ...
        'FaceAlpha',0.2, ...
        'EdgeColor','none', ...
        'HandleVisibility','off');

end


hRMS = plot(time,rmsEnvelope,'b','LineWidth',1.2);

hON = yline(onThreshold,'r--','ON Threshold');
hOFF = yline(offThreshold,'g--','OFF Threshold');


for k = 1:numberOfContractions

    xline(onsetTime(k),'r:','LineWidth',1.2);
    xline(offsetTime(k),'g:','LineWidth',1.2);

end

title(sprintf('Muscle Activation - %d contractions', ...
    numberOfContractions));

xlabel('Time (s)');
ylabel('RMS (ADC counts)');

legend([hRMS hON hOFF], ...
    {'RMS Envelope','ON Threshold','OFF Threshold'}, ...
    'Location','northwest');

grid on;
box off;
xlim([0 duration]);


ax4 = nexttile;

yyaxis left;

h1 = plot(featureTime,RMS,'b','LineWidth',1.1);
hold on;

h2 = plot(featureTime,MAV,'r--','LineWidth',1.1);

ylabel('RMS / MAV (ADC counts)');

yyaxis right;

h3 = plot(featureTime,ZC,'k','LineWidth',1);

ylabel('Zero Crossings');

title('EMG Features');
xlabel('Time (s)');

legend([h1 h2 h3], ...
    {'RMS','MAV','Zero Crossings'}, ...
    'Location','northwest');

grid on;
box off;
xlim([0 duration]);


linkaxes([ax1 ax2 ax3 ax4],'x');


sgtitle('EMG Analysis | ESP32 | 5000 Hz', ...
    'FontSize',16,'FontWeight','bold');


fprintf('\n========== CONTRACTION RESULTS ==========\n');

fprintf('Number of contractions detected: %d\n', ...
    numberOfContractions);

disp(ContractionTable);


writetable(FeatureTable,'EMG_Features.csv');

writetable(ContractionTable,'EMG_Contractions.csv');

fprintf('\nFeature and contraction CSV files saved.\n');


function p = percentile_local(x,percent)

    x = sort(x(:));

    n = length(x);

    if n == 0
        p = NaN;
        return;
    end

    position = 1+(n-1)*percent/100;

    lowerIndex = floor(position);
    upperIndex = ceil(position);

    if lowerIndex == upperIndex

        p = x(lowerIndex);

    else

        weight = position-lowerIndex;

        p = x(lowerIndex)*(1-weight) + ...
            x(upperIndex)*weight;

    end

end
