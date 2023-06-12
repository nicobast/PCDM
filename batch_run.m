
files = dir("input\");
files = {files.name}; %save as cells
output = {};

%remove files: 55, 139, 222,251, 340
files{55} = [];
files{139} = [];
files{222} = [];
files{251} = [];
files{340} = [];
%8, 12 

for i=7:numel(files)

    disp(files{i})
    disp(i)

    load(files{i});
    data = convert_R_output_toCells_2runs(input);
    [parameters, estimates] = fitModel(data);
    
    disp(estimates.Rsq)
    disp(estimates.gain)
    
    save(strcat('output/pcdm_results_',files{i}),'parameters','estimates');
    output{i} = estimates;
    output{i}.name = files{i};

end 

save('output/estimates_2runs','output')