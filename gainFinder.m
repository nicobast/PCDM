function f = gainFinder(d,ii)
% gainFinder.m
%     
%     Cite: Burlingham C*, Mirbagheri S*, Heeger DJ (2022). Science 
%           Advances. *Equal Authors
%
%     Date: 2/9/22
%
%     Purpose: Solves for best-fit gain and generator function(s), and
%              returns model predictions and goodness of fit.
%

threshold = 1; % arbitrary, but fixed 
d.sacRate2{ii}(d.sacRate2{ii}==0) = eps; % if rate is zero set it to a very small number so we don't reach inifinity at end of gaussian tail. Future implementations can instead regularize missing data..
Generator = 1-d.sacRate2{ii};
for kk = 1:size(d.sacRate2{ii}) %% kk index is for trial types
    Generator(kk,:) = norminv(Generator(kk,:),0,1);
    Generator(kk,:)  = threshold - Generator(kk,:);
    Generator(kk,:) = Generator(kk,:)-nanmean(Generator(kk,:)); % mean-subtract generator function
end

MIR = d.parametricLinearFilter-d.parametricLinearFilter(1);


keyboard
% create generator series
generatorSeries = zeros(length(d.pupilTS{ii}),max(d.trialTypes{ii})); 
predMatrix = zeros(length(d.pupilTS{ii}),max(d.trialTypes{ii})); 
for kk = 1:max(d.trialTypes{ii})
    thisType = find(d.trialTypes{ii}==kk);
    for jj=1:length(thisType) % looping through trials of that type
        generatorSeries(d.trInds{ii}(thisType(jj),1):d.trInds{ii}(thisType(jj),2),kk) = Generator(1,1:d.trInds{ii}(thisType(jj),2)- d.trInds{ii}(thisType(jj),1)+1)';
    end
    pred = conv(MIR,generatorSeries(:,kk));
    predMatrix(:,kk) = pred(1:length(d.pupilTS{ii}));
end

DM = [ones(length(d.pupilTS{ii}),1), predMatrix];
sol = regress(d.pupilTS{ii}',DM);
gain = sol(2:end);

pred = gain'*predMatrix';


trAvgPredMat = NaN(length(d.trInds{ii}),length(d.TEPR{ii}));
for ll = 1:length(d.trInds{ii})
    if ll == length(d.trInds{ii})
        trAvgPredMat(ll,1:length(pred(d.trInds{ii}(ll,1):end))) = pred(d.trInds{ii}(ll,1):end);
    else
        trAvgPredMat(ll,1:(d.trInds{ii}(ll,2)-d.trInds{ii}(ll,1))+1) = pred(d.trInds{ii}(ll,1): d.trInds{ii}(ll,2));
    end
end

pred = downsample(nanmean(trAvgPredMat),d.downsampleRate,1);


offset = mean(d.TEPR{ii});


SSres = sum((d.TEPR{ii}-(pred+offset)).^2);
SStot = sum((d.TEPR{ii}-nanmean(d.TEPR{ii})).^2);
Rsq = 1 - (SSres./SStot);

%{
SSres = sum((d.pupilTS{ii}-(pred)).^2);
SStot = sum((d.pupilTS{ii}-nanmean(d.pupilTS{ii})).^2);
Rsq = 1 - (SSres./SStot);
%}



%{
for kk = 1:size(Generator,1)
    predT = cconv(MIR,Generator(kk,:),size(Generator,2));
    predT = predT- (mean(predT,2));
    predT = downsample(predT,d.downsampleRate,1);
    predEach(kk,:) = predT;
    
    DM = [ones(length(d.TEPR{ii}),1), predEach(kk,:)'];
    sol = regress(d.TEPR{ii}',DM);
    
    gain(kk) = sol(2:end);
end

pred = gain*predEach; % final prediction

offset = (mean(d.TEPR{ii})-mean(pred));

SSres = sum((d.TEPR{ii}-(pred+offset)).^2);
SStot = sum((d.TEPR{ii}-nanmean(d.TEPR{ii})).^2);
Rsq = 1 - (SSres./SStot);
%}



f.gain = gain;
f.Generator = Generator;
f.offset = offset;
f.Rsq = Rsq;
f.pred = pred;

end

