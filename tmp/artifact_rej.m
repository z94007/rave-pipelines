
% --- Params ---
%fname = '/Users/beauchamplab/Desktop/PAV079stim/raw/PAV079_Datafile_015.ns5';
fname = '/Users/beauchamplab/PennNeurosurgery Dropbox/Xiang Zhang/PennEMU/EMU_Data/PAV083/iEEGData/PAV083_Datafile_053.ns5';

ch = [118 120];
fs = 30e3;

syncThresh = 1000;
minPeakDistTrials = 4*fs;
minPeakDistEdges  = 0.4*fs;
stimlength = 0.5;
stimfreq = 50;

snipWin = round(fs/stimfreq);      % samples
nPerPulse = stimfreq * stimlength;
%%

% --- Load ---
ns5 = openNSx(fname, 'uv','noalign' ,'channels',ch);
%%
% If you truly only loaded 2 channels, use 1 & 2:
bipolar = double(ns5.Data(1,:))%- double(ns5.Data(2,:));

plot(bipolar);
%%

% --- Find sync channel robustly (if needed) ---
% (If you already know sync is separate channel, load it explicitly instead of guessing via labels)
%%
NSx = openNSx(fname, 'noread');

% Get channel labels
labels = {NSx.ElectrodesInfo.Label};

% Find the channel whose label contains 'Events'
idx = find(contains(labels, 'Events', 'IgnoreCase', true));

if isempty(idx)
    error('No channel containing "Events" was found.');
end


% Now load that channel
sync = openNSx(fname, 'uv', 'noalign', ...
    ['c:' num2str(idx)], 'read');

% Thresholding
syncBin = sync.Data > syncThresh;

% Find pulse segments (connected components)
d = diff([0 syncBin 0]);
onset  = find(d == 1);
offset = find(d == -1) - 1;

% Guard: ensure pairs
nPulses = min(numel(onset), numel(offset));
onset = onset(1:nPulses);
offset = offset(1:nPulses);
% Generate locs inside each pulse window
locCell = cell(nPulses,1);
for k = 1:nPulses
    last = offset(k) - snipWin;
    if last <= onset(k), continue; end
    locCell{k} = round(linspace(onset(k), last, nPerPulse));
end
loc = [locCell{:}];
loc = loc(:)';

% Bounds check
loc = loc(loc > 0 & (loc + snipWin) <= numel(bipolar));
%%
% Build snips with preallocation
nLoc = numel(loc);
snips = zeros(snipWin+1, nLoc);
for i = 1:nLoc
    snips(:,i) = bipolar(loc(i):(loc(i)+snipWin));
end
plot(snips)
%%
% Align by local max within a small window (you can tune this)
searchIdx = 15:20;
[min_val, ix_min] = min(snips(searchIdx,:), [], 1);
[max_val, ix_max] = max(snips(searchIdx,:), [], 1);
if abs(mean(min_val)) >= abs(mean(max_val)) 
    ix = ix_min;
else
    ix = ix_max;
end

shift = ix - ix(1);
locAligned = loc - (shift(1) - shift);

% Rebuild aligned snips (with bounds check again)
locAligned = locAligned(locAligned > 0 & (locAligned + snipWin) <= numel(bipolar));
nLoc2 = numel(locAligned);
snips2 = zeros(snipWin+1, nLoc2);
for i = 1:nLoc2
    snips2(:,i) = bipolar(locAligned(i):locAligned(i)+snipWin);
end

% Template estimate and subtraction
ms = detrend(mean(snips2(25:151,:),1));  % column
%ms = ms - ms(end);
ms2 = mean(snips2,2);
plot(snips2)
%% -----
psnips = snips2;
psnips(601,:)=NaN;
psnips(1:20,:) = NaN;

plot(psnips)

%% -----
X = psnips';   % 12000 x 150  (rows = observations)
X = X(:, ~all(isnan(X), 1));

% Optional but usually recommended
%Xz = zscore(X, 0, 1);   % normalize each feature across observations
Xz= X;


% PCA
[coeff, score, latent, ~, explained, mu] = pca(Xz);

% 2D projection of the 12000 observations
Y2 = score(:, 1:2);    % 12000 x 2

scatter(Y2(:,1),Y2(:,2))
%% --
temp1 = detrend(mean(X,1),0);
plot(temp1)
hold on;
plot(mean(X,1));
%% --- Subtract template from non-NaN part of psnips ---

% psnips: samples x pulses, here usually 151 x nLoc2
% temp1 was computed from X = psnips', after removing all-NaN columns
% So temp1 corresponds to rows in psnips that are not all NaN

validRows = find(~all(isnan(psnips), 2));   % usually 21:150

if numel(validRows) ~= numel(temp1)
    error('Length mismatch: validRows has %d samples but temp1 has %d samples.', ...
        numel(validRows), numel(temp1));
end

psnips_sub = psnips;

% subtract temp1 from every pulse, only for non-NaN rows
psnips_sub(validRows, :) = psnips_sub(validRows, :) - temp1(:);

figure;
plot(psnips_sub);
title('Template-subtracted psnips with NaN artifact samples');


%% --- Fill corrected snippets back to original bipolar data ---

bipolar_clean = bipolar;   % keep original, create cleaned copy

% make sure locAligned and psnips_sub columns match
if numel(locAligned) ~= size(psnips_sub, 2)
    error('locAligned length does not match number of psnips columns.');
end

for i = 1:numel(locAligned)

    idx = locAligned(i):(locAligned(i) + snipWin);

    % safety check
    if idx(1) < 1 || idx(end) > numel(bipolar_clean)
        continue;
    end

    % backfill corrected snip;
    % NaN positions mark the artifact region to be filled later
    bipolar_clean(idx) = psnips_sub(:, i);
end

figure;
plot(bipolar_clean);
title('Bipolar after template subtraction, before NaN filling');


%% --- Fill NaN parts using moving average ---

nanMask = isnan(bipolar_clean);

% choose window size for moving average
% e.g. 101 samples = about 3.37 ms at 30 kHz
maWin = 101;

% fill NaNs by local moving average
bipolar_filled = bipolar_clean;
bipolar_filled = fillmissing(bipolar_filled, 'movmean', maWin);

% In case edge NaNs remain, fill them with nearest non-NaN value
bipolar_filled = fillmissing(bipolar_filled, 'nearest');

figure;
plot(bipolar_filled);
title('Final bipolar after moving-average NaN filling');


%% --- Optional: compare before and after ---

t = (0:numel(bipolar)-1) / fs;

figure;
plot(t, bipolar, 'k');
hold on;
plot(t, bipolar_filled, 'r');
xlabel('Time (s)');
ylabel('\muV');
legend({'Original bipolar', 'Cleaned bipolar'});
title('Original vs cleaned bipolar');
%% --- Save the cleaned data ---

%outFile = '/Users/beauchamplab/Desktop/PAV079stim/raw/PAV081_Datafile_014_cleaned_bipolar.mat';
%save(outFile, "bipolar_filled");
 
