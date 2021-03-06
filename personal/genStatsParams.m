function stats_params = genStatsParams(project_name)

%% INPUTS:
%   project_name: task name

switch project_name
    case 'MMR'
        stats_params.task_win = [0 2];
        stats_params.bl_win = [-0.2 0];
    case 'Memoria'
        stats_params.task_win = [0 3];
        stats_params.bl_win = [-0.5 0];
    case 'GradCPT'
        stats_params.task_win = [0 0.8];
        stats_params.bl_win = [-0.2 0];
end

stats_params.nreps= 100000;
stats_params.freq_range = [70 180];
stats_params.paired = false;
stats_params.noise_method = 'trials';
stats_params.alpha = 0.05;


