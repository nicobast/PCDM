function [d, op] = dataAnalysis(in)
% dataAnalysis.m
%
%     Cite: Burlingham C*, Mirbagheri S*, Heeger DJ (2022). Science
%           Advances. *Equal Authors
%
%     Date: 2/9/21
%
%     Purpose: Pre-processes eye data and estimates inputs to model.
%
%              Specifically does the following: blink interpolation
%              (optional), bandpass filtering of pupil data, saccade
%              detection, deconvolution of saccade-locked pupil response,
%              estimation of task-evoked pupil response (can format data
%              to lock pupil response to various events, e.g., task onset,
%              cues, or button press), estimation of saccade rate
%              function(s) (one per trial type, e.g., correct vs. error
%              trials).
%
%     Inputs:
%
%              input struct "in" with fields containing cell array with one
%              cell per run of data. Field names:
%
%              - yPos: horizontal gaze position in dva (column vector)
%              - yPos: vertical gaze position in dva (column vector)
%                      (the coodinates (0,0) should be at fixation)
%              - pupilArea: pupil area (column vector)
%              - startInds: trial start indexes in samples (n x 2 matrix
%                with trial start and end times, n is number of trials)
%              - sampleRate: sampling rate of eye tracker (Hz)
%              - trialTypes: trial types (e.g., easy / hard, or corr\error)
%                integers for each trial, e.g. 1,2,3,4,5 (1 x n vector)
%              - predictionWindow: time window beyond trial onset to make a
%                prediction within (e.g. 4 sec in a jittered ISI expt)
%
%              options struct "op" with field names:
%
%              - interpolateBlinks (0 or 1) to interpolate blinks from pupil
%                time series (only use if you are inputting eyeLink data,
%                otherwise, do this step yourself)
%              - downsampleRate for deconvolution of saccade-locked pupil
%                response (default 5)
%              - fittimeSeries (0 or 1) to base the gain estimates on the
%                entire time series (like an fMRI linear systems analysis).
%                This is useful if you have overlapping trial types or if
%                you want to account for shared variance between trial
%                types. If set to 0, it will fit each trial type separately
%                based on the trial-average.
%

%adaptations from original
% -  downsampling needed  --> PHASE to be a scalar with value <= 0
%       only works if function downsample is used
%       without PHASE argument - see gainFinder line 110
% - issues: 
%       - in.predictionWindow>maxTrialLength (line 117) - compares
%         time window in seconds to number of samples -->
%         predictionWindow should be in samples (not time)

%% Set options
op.interpolateBlinks = 1; % 1, blink interpolation on; 0, interpolation off (use this if your input data is already blink interpolated)
op.downsampleRate = 2; % default 5 - downsample rate for the deconvolution design matrix. Higher numbers makes code run faster, but shouldn't be set higher than Nyquist frequency.
op.fitTimeseries = 0; % if you want to estimate gain based on the whole pupil time series, set to 1. To just estimate gain based just on the trial-average (per trial type), set to 0. If you're just fitting more than one overlapping trial type and you want to take into account variance shared between them, set this to 1

in.putativeIRFdur = 4; % how long you think the saccade-locked pupil response is in seconds. User-defined, but 4 s is a good estimate according to our results and the literature
in.predictionWindow = 0.5; % The time window you want to make the prediction for the TEPR, beyond the trial onset time (in seconds). Usually the max trial length, but can be shorter if you want.

%%further options - reduce magic numbers
op.change_cutoff_by_samplingrate = 5; % (10) 10 is default for 1Khz sampling rate
op.low_bandpass_filter_range = [0.03 , 10]; %[0.03 , 10] from to in Hz
op.blinkint_vel_thres_on = 5; % (5)velocity threshold of pupil onset detection
op.blinkint_vel_thres_on = 4; % (4) velocity threshold of pupil offset detection
op.blinkint_window_from_onset = 50; % (50) time in ms from zero looks for blink onset, offset
op.blinkint_min_dur = 75; % (75) the minimum duration in ms required to form a valid region of data

op.velvec_method = 1; %(3) see velvec - different methods for sampling rates
op.rel_vel_thres = 8; %(8) see microsac - relative velocity threshold
op.min_sac_dur = 7; %(7) see microsac - minimal saccade duration


%%
numRuns = length(in.pupilArea); % number of runs of data (number of cells passed as input)

for ff = 1:numRuns
    disp(['Processing Run #' num2str(ff)])
    
    %% Interpolate blinks (Mathot's method, modified for Parker & Denison 2020)
    if op.interpolateBlinks == 1
        in.pupilArea{ff}((isnan(in.pupilArea{ff}))) = 0; % set NaN regions to 0 for interp algorithm
        aboveT = find(abs(diff(in.pupilArea{ff})) > (in.sampleRate{ff}/op.change_cutoff_by_samplingrate) ); % set other blink regions that were not detected by EyeLink firmware to 0 as well.  velocity threshold as defined in samples should depend on sampleRate
        in.pupilArea{ff}(aboveT) = 0; % set other blink regions that were not detected by EyeLink firmware to 0 as well
        in.pupilArea2 = blinkinterp(in.pupilArea{ff}',in.sampleRate{ff},op.blinkint_vel_thres_on,op.blinkint_vel_thres_on,op.blinkint_window_from_onset,op.blinkint_min_dur); % default options
    end
    
    disp(length(aboveT)) %diagnostic testing
    
    %% Band-pass filter pupil signal
    baseline = nanmean(in.pupilArea2); % get baseline first
    in.pupilArea3 = myBWfilter(in.pupilArea2,op.low_bandpass_filter_range,in.sampleRate{ff},'bandpass');
    d.pupilTS{ff} = in.pupilArea3; % save out timeseries
    
    %% Detect small saccades and microsaccades (method of Engbert & Mergenthaler 2006)
    vel = vecvel([in.xPos{ff} in.yPos{ff}], in.sampleRate{ff}, op.velvec_method); % compute eye velocity
    d.saccTimes{ff} = microsacc([in.xPos{ff} in.yPos{ff}], vel, op.rel_vel_thres , op.min_sac_dur); % detect (micro)saccade times based on eye velocity
    
    %% Estimate saccade-locked pupil response
    
    % downsample the pupil data
    sacOnset = d.saccTimes{ff}(:,1); % determine the indexes that saccades begin
    pupilDN = downsample(in.pupilArea3,op.downsampleRate);
    sacTimeInd = floor(sacOnset/op.downsampleRate)+1;
    
    % make a convolution matrix with width (putative IRF length)
    saccadeTimeVector = zeros(1, length(pupilDN)); saccadeTimeVector(sacTimeInd) = 1;
    nTrials = length(in.startInds);
    putativeIRFlength = in.putativeIRFdur*in.sampleRate{ff}/op.downsampleRate;
    for ii=1:putativeIRFlength
        Sacmatrix(1:length(pupilDN),ii) = [zeros(1,ii-1) saccadeTimeVector(1:length(pupilDN)-ii+1)]';
    end
    
    Sacmatrix = Sacmatrix(1:length(pupilDN),:);
    d.sacIrf(ff,:) = pupilDN * pinv(Sacmatrix'); % deconvolve
    
    %% Estimate task-evoked pupil response
    trialLengths = in.startInds{ff}(:,2)-in.startInds{ff}(:,1);
    maxTrialLength = max(trialLengths)+1; % samples
    
    if in.predictionWindow>maxTrialLength
        error('Prediction window must be longer than max trial length')
    elseif maxTrialLength/in.sampleRate{ff} > in.predictionWindow*1.5 || maxTrialLength/in.sampleRate{ff} > 6
        warning('Your trials are quite long, which may cause slow drifts in arousal within a trial. Try shortening the prediction windowfirst and if that doesn''t help the model fits, you may need to fit a second gain in the second half of the trial to capture changes in arousal happening during the ISI.')
    end
    
    % make a convolution matrix with width (max trial length)
    trialStartTimeDN = floor(in.startInds{ff}(:,1)/op.downsampleRate)+1;
    trialStartTimeVec = zeros(1, length(pupilDN)); trialStartTimeVec(trialStartTimeDN) = 1;
    
    maxTrialLengthDN = maxTrialLength/op.downsampleRate;
    for ii=1:maxTrialLengthDN
        TEPRmatrix(1:length(pupilDN),ii) = [zeros(1,ii-1) trialStartTimeVec(1:length(pupilDN)-ii+1)]';
    end
    
    TEPRmatrix = TEPRmatrix(1:length(pupilDN),:);
    d.TEPR{ff} = ( (pupilDN-nanmean(pupilDN)) * pinv(TEPRmatrix') ) + baseline; % deconvolve
    
    if op.fitTimeseries == 0
        in.numTrialTypes{ff} = max(in.trialTypes{ff}); % number of trial types within the run of data. Shouldn't be set too high without feeding in much more data to constrain estimation.
        
        for ii = 1:double(in.numTrialTypes{ff}) % loop over trial types
            trialNumsPerType{ii} = find(in.trialTypes{ff}(1:end-1)==ii);
            nTrialsPerType(ii) = length(trialNumsPerType{ii});
            
            startIndsThisTrialTypeDN = trialStartTimeDN(trialNumsPerType{ii});
            trialStartTimeVecThisTrialTypeDN = zeros(1, length(pupilDN)); trialStartTimeVecThisTrialTypeDN(startIndsThisTrialTypeDN) = 1;
            
            for jj=1:maxTrialLengthDN
                TEPRmatrixTT{ii}(1:length(pupilDN),jj) = [zeros(1,jj-1) trialStartTimeVecThisTrialTypeDN(1:length(pupilDN)-jj+1)]';
            end
            
            
            TEPRmatrixTT{ii} = TEPRmatrixTT{ii}(1:length(pupilDN),:);
            d.TEPR_TT{ff}(ii,:) = ( (pupilDN-nanmean(pupilDN)) * pinv(TEPRmatrixTT{ii}') ) + baseline; % deconvolve
            
        end
    end
    
    %{
    % to simply find trial-avg up to prediction window, do this:
    preserveInds = [];
    for nn = 1:length(in.startInds{ff})
        preserveInds = [preserveInds trialStartTimeDN(nn):trialStartTimeDN(nn)+in.predictionWindow*in.sampleRate{ff}/op.downsampleRate-1];
    end
    pupilDN2 = pupilDN(preserveInds);
    pupilAvg = nanmean(reshape(pupilDN2',in.predictionWindow*in.sampleRate{ff}/op.downsampleRate,length(in.startInds{ff}))')+baseline;
    %}
    
    %% Estimate saccade rate function(s) (one per trial type)
    in.numTrialTypes{ff} = max(in.trialTypes{ff}); % number of trial types within the run of data. Shouldn't be set too high without feeding in much more data to constrain estimation.
    
    for ii = 1:double(in.numTrialTypes{ff}) % loop over trial types
        trialNumsPerType{ii} = find(in.trialTypes{ff}(1:end-1)==ii);
        nTrialsPerType(ii) = length(trialNumsPerType{ii});
        rateRaster{ii} = nan(nTrialsPerType(ii), maxTrialLength);
        saccadeTimeVector2{ii} = zeros(1, length(in.pupilArea3));
        saccadeTimeVector2{ii}(sacOnset) = 1;
        
        for trNum = trialNumsPerType{ii}
            rateRaster{ii}(trNum,1:in.startInds{ff}(trNum,2) - in.startInds{ff}(trNum,1)+1) = saccadeTimeVector2{ii}(in.startInds{ff}(trNum,1):in.startInds{ff}(trNum,2));
        end
        
        d.sacRateTemp = nanmean(rateRaster{ii});
        d.sacRate{ff}(ii,:) = d.sacRateTemp(1:maxTrialLength);
        
        d.nSaccsPerTrialType{ff}(ii) = nansum(nansum(rateRaster{ii}));
        if d.nSaccsPerTrialType{ff}(ii) < 100
            warning(['Too few saccades for trial type #' num2str(ii) '. Add more data and try again. In general the amount of data per trial type should be roughly the same or else you may over-estimate gain for the trial type with less data.'])
        end
    end
    
end

%% Save out other variables
d.trialTypes = in.trialTypes;
d.sampleRate = in.sampleRate{1}; % there should be only one sampling rate for all data, or remove the {1}
d.downsampleRate = op.downsampleRate;
d.trInds = in.startInds;
d.predictionWindow = in.predictionWindow;

end