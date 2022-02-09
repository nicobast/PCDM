function [d,f] = fitModel(in)
% fitModel.m
%
%     Authors: Charlie S. Burlingham & Saghar Mirbagheri
%
%     Date: 2/8/21
%
%     Purpose: Fits Pupil Common Drive Model (PCDM) to pupil and saccade 
%              data. Estimates model inputs and parameters: trial-average 
%              pupil response, linear filter, post-saccadic refractory 
%              period, saccade rate function, generator function, and gain.
%
%     Usage: 
%

%%

% Load in data struct "in" (see dataAnalysis for format and details)
d = dataAnalysis(in); % d is input structure

% estimate inter-saccadic interval and parameter k
[k, kCI] = fitK(d.saccTimes, d.sampleRate, 1);

% adjust saccade rate functions for estimated post-saccadic refractory period
numRuns = size(d.sacIrf,1); % loop across runs
for ii = 1:numRuns
    d.sacRate2{ii} = k.*d.sacRate{ii};
end

% estimate parametric linear filter from run-average saccade-locked pupil response
IrfAvg = nanmean(d.sacIrf); % avg. saccade-locked IRF across all runs 
[parametricLinearFilter, params, Rsq1, normFactor] = fitParametricPuRFfromData(IrfAvg,d.sampleRate./d.downsampleRate,d.sampleRate,1);
d.parametricLinearFilter = parametricLinearFilter;


% fit and evaluate model parameters
for ii = 1:numRuns % loop across runs
    temp = gainFinder(d,ii);
    f.gain{ii} = temp.gain;
    f.Generator{ii} = temp.Generator;
    f.offset{ii} = temp.offset;
    f.Rsq{ii} = temp.Rsq;
    f.pred{ii} = temp.pred;
end

% plot data and model fits
plotFits(d,f);

end