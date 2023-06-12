   
load('387103247866_wave2.mat');
data = convert_R_output_toCells_2runs(input);
[parameters, estimates] = fitModel(data);

disp(estimates.Rsq)
disp(estimates.gain)

save(strcat('output/results_TEST'),'parameters','estimates')
