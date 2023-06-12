
files = dir("input\");
files = {files.name}; %save as cells
%output = {};

%remove files: 55, 56, 139, 222,251, 340
% files{55} = [];
% files{139} = [];
% files{222} = [];
% files{251} = [];
% files{340} = [];
% retest 55

for i=341:numel(files)

    disp(files{i})
    disp(i)

    load(files{i});
    data = convert_R_output_toCells(input);
    [parameters, estimates, settings] = fitModel(data);
    
    disp(estimates.Rsq)
    disp(estimates.gain)
    
    save(strcat('output/pcdm_results_',files{i}),'parameters','estimates');
    output{i} = estimates;
    output{i}.name = files{i};

end 

save('pcdm_estimates_1run_290323','output','settings')