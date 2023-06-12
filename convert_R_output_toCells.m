function [output] = convert_R_output_toCells(input)

%convert R output to correct input for PCDM
output.xPos = num2cell(input.xPos,[1 2]);
output.yPos = num2cell(input.yPos,[1 2]);
output.pupilArea= num2cell(input.pupilArea,[1 2]);
output.startInds= num2cell(double(input.startInds),[1 2]);
output.sampleRate= num2cell(input.sampleRate,[1 2]);
output.trialTypes= num2cell(transpose(input.trialTypes),[1 2]); %first transpose 

%input.pupilArea{1} = input.pupilArea{1}*100;

end