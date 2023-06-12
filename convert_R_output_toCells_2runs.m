function [output] = convert_R_output_toCells_2runs(input)

%convert R output to correct input for PCDM
output.xPos = {};
output.xPos{1} = input.xPos_1;
output.xPos{2} = input.xPos_2;

output.yPos = {};
output.yPos{1} = input.yPos_1;
output.yPos{2} = input.yPos_2;

output.pupilArea = {};
output.pupilArea{1} = input.pupilArea_1; 
output.pupilArea{2} = input.pupilArea_2; 

output.startInds = {};
output.startInds{1} = horzcat(input.startInds_1s,input.startInds_1e);
output.startInds{2} = horzcat(input.startInds_2s,input.startInds_2e);

output.sampleRate = {};
output.sampleRate{1} = input.sampleRate_1;
output.sampleRate{2} = input.sampleRate_2;

%triaType needs to be transposed
output.trialTypes = {};
output.trialTypes{1} = transpose(input.trialTypes_1);
output.trialTypes{2} = transpose(input.trialTypes_2);

end