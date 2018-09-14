%% Branch 1. basic config - PEDRO
computer = 'Amy_iMAC';
AddPaths(computer)

parpool(4) % initialize number of cores

%% Initialize Directories
% project_name = 'Calculia_production';
% project_name = 'MMR';
project_name = 'Memoria';
% project_name = 'MFA';
% project_name = '7Heaven';
% project_name = 'Scrambled';
% project_name = 'UCLA';
% project_name = 'Calculia';
% project_name = 'Calculia_China';
% project_name = 'Number_comparison';
% project_name = 'GradCPT';

%% Create folders
% sbj_name = 'S15_89b_JQ';
sbj_name = 'S14_69b_RT';
% sbj_name = 'C17_13';
% sbj_name = 'S17_116';
% sbj_name = 'S18_127';

% Center
% center = 'China';
center = 'Stanford';

%% Get block names
block_names = BlockBySubj(sbj_name,project_name);
% Manually edit this function to include the name of the blocks:

% Make sure your are connected to CISCO and logged in the server
set_freesurfer_dir = false;
dirs = InitializeDirs(computer, project_name,sbj_name,set_freesurfer_dir);

%% Get iEEG and Pdio sampling rate and data format
[fs_iEEG, fs_Pdio, data_format] = GetFSdataFormat(sbj_name, center);

%% Create subject folders
load_server_files = true;
CreateFolders(sbj_name, project_name, block_names, center, dirs, data_format,load_server_files) 
%%% IMPROVE uigetfile to go directly to subject folder %%%

% this creates the fist instance of globalVar which is going to be
% updated at each step of the preprocessing accordingly
% At this stage, paste the EDF or TDT files into the originalData folder
% and the behavioral files into the psychData
% (unless if using CopyFilesServer, which is still under development)

%% Copy the iEEG and behavioral files from server to local folders
% Login to the server first?
% Should we rename the channels at this stage to match the new naming?
% This would require a table with chan names retrieved from the PPT
parfor i = 1:length(block_names)
    CopyFilesServer(sbj_name,project_name,block_names{i},data_format,dirs)
end
% In the case of number comparison, one has also to copy the stim lists

%% Get marked channels and demographics
[refChan, badChan, epiChan, emptyChan] = GetMarkedChans(sbj_name);
ref_chan = [];
epi_chan = [];
empty_chan = []; % INCLUDE THAT in SaveDataNihonKohden SaveDataDecimate

%% Branch 2 - data conversion - PEDRO
if strcmp(data_format, 'edf')
    SaveDataNihonKohden(sbj_name, project_name, block_names, dirs, ref_chan, epi_chan, empty_chan) %
    % MAYBE NOT CHANGE DC CHANNEL LABELS. No need to call them PDIO? 
elseif strcmp(data_format, 'TDT')
    SaveDataDecimate(sbj_name, project_name, block_names, fs_iEEG, fs_Pdio, dirs, ref_chan, epi_chan, empty_chan) %% DZa 3051.76
else
    error('Data format has to be either edf or TDT format')
end

%% Convert berhavioral data to trialinfo
switch project_name
    case 'MMR'
%         OrganizeTrialInfoMMR(sbj_name, project_name, block_names, dirs) %%% FIX TIMING OF REST AND CHECK ACTUAL TIMING WITH PHOTODIODE!!! %%%
        OrganizeTrialInfoMMR_rest(sbj_name, project_name, block_names, dirs) %%% FIX ISSUE WITH TABLE SIZE, weird, works when separate, loop clear variable issue
    case 'Memoria'
        OrganizeTrialInfoMemoria(sbj_name, project_name, block_names, dirs)
    case 'UCLA'
        OrganizeTrialInfoUCLA(sbj_name, project_name, block_names, dirs) % FIX 1 trial missing from K.conds?
    case 'Calculia_China'
        OrganizeTrialInfoCalculiaChina(sbj_name, project_name, block_names, dirs) % FIX 1 trial missing from K.conds?
    case 'Calculia_production'
        OrganizeTrialInfoCalculia_production(sbj_name, project_name, block_names, dirs) % FIX 1 trial missing from K.conds?
    case 'Number_comparison'
        OrganizeTrialInfoNumber_comparison(sbj_name, project_name, block_names, dirs) % FIX 1 trial missing from K.conds?        
    case 'GradCPT'
        OrganizeTrialInfoGradCPT(sbj_name, project_name, block_names, dirs,1,'1')
end


% segment_audio_mic(sbj_name,project_name, dirs, block_names{1}) 


%% Branch 3 - event identifier
EventIdentifier(sbj_name, project_name, block_names, dirs)
EventIdentifier_Memoria(sbj_name, project_name, block_names, dirs)

% if strcmp(project_name, 'Number_comparison')
%     event_numcomparison_current(sbj_name, project_name, block_names, dirs, 9) %% MERGE THIS
% else
%     EventIdentifier(sbj_name, project_name, block_names, dirs, 9, 0) % new ones, photo = 1; old ones, photo = 2; china, photo = varies, depends on the clinician, normally 9.
% end
% Fix it for UCLA
% subject 'S11_29_RB' exception = 1 for block 2 


%% Branch 4 - bad channel rejection
BadChanReject(sbj_name, project_name, block_names, dirs)
% 1. Continuous data
%      Step 0. epileptic channels based on clinical evaluation from table_.xls
%      Step 1. based on the raw power
%      Step 2. based on the spikes in the raw signal
%      Step 3. based on the power spectrum deviation
%      Step 4. Bad channel detection based on HFOs

% Creates the first instance of data structure inside car() function
% TODO: Create a diagnostic panel unifying all the figures

%% Branch 5 - Time-frequency analyses
% Load elecs info
load(sprintf('%s/originalData/%s/global_%s_%s_%s.mat',dirs.data_root,sbj_name,project_name,sbj_name,block_names{1}),'globalVar');
elecs = setdiff(1:globalVar.nchan,globalVar.refChan);

for i = 1:length(block_names)x
%     for ei = 1:length(elecs)
    parfor ei = 1:length(elecs)
        WaveletFilterAll(sbj_name, project_name, block_names{i}, dirs, elecs(ei), 'HFB', [], [], [], 'Band') % only for HFB
        WaveletFilterAll(sbj_name, project_name, block_names{i}, dirs, elecs(ei), 'SpecDenseLF', [], [], true, 'Spec') % across frequencies of interest
    end
end

%% Branch 6 - Epoching, identification of bad epochs and baseline correction
switch project_name
    case 'GradCPT'
        blc_params.run = false;
        tmin = -0.5; %-0.8
        tmax = 1.6; % 0.8
    case 'Memoria'
        blc_params.run = true; % or false
        tmin = -0.5;
        tmax = 7;
        blc_params.win = [-.5 0];
end
blc_params.locktype = 'stim';
noise_params.method = 'trials';
noise_params.noise_fields_trials = {'bad_epochs_HFO','bad_epochs_raw_HFspike'};

for i = 1:length(block_names)
    bn = block_names{i};
    parfor ei = 1:length(elecs) 
        EpochDataAll(sbj_name, project_name, bn, dirs,elecs(ei),'stim', tmin, tmax, 'HFB', [],[], blc_params,noise_params,'Band')
        EpochDataAll(sbj_name, project_name, bn, dirs,elecs(ei),'stim', tmin, tmax, 'SpecDenseLF', [],[], blc_params,noise_params,'Spec')
    end
end

% Bad epochs identification
%      Step 1. based on the raw signal
%      Step 2. based on the spikes in the raw signal
%      Step 3. based on the spikes in the HFB signal or other freq bands

%% RT phase correlation
phaseRT = phaseRTCorrAll(sbj_name, project_name, block_names,dirs,'stim',elecs);
plotPhaseRTCorr(sbj_name,project_name,dirs,61,[])

%% PLV
% S17_116
% SPL = {'RPG1','RPG2','RPG3','RPG9','RPG10'};
% PMC = {'RPT1'};
% VIS = {'RPG41','RPG42','RPG49','RPG57','RPG58','RO6','RO7','RO8','RO14'};
% elecs1 = PMC;
% elecs2 = VIS;

% S18_119
% SPL = {'LRSC7','LRSC8','LRSC9','LRSC10'}; 
% INS = {'LdINS1','LdINS2'};
% PMC = {'LRSC1','LRSC2','RRSC1','RRSC2','RRSC3'};
% elecs1 = SPL;
% elecs2 = PMC;

% S18_123
% SPL = {'LSPS9','LSPS10'};
% PMC = {'LIHG24'};
% VIS = {'LIHG32','LIOG7','LIOG14','LLPG1'};
% elecs1 = PMC;
% elecs2 = VIS;

% S18_124
SPL = {'LDP6','LDP7','RDP5','RDP6','RDP7'};
PMC = {'LDP1'};
INS = {'LAI6','LAI7'};
VIS = {'LTP1'};
elecs1 = PMC;
elecs2 = VIS;

% S14_69b
SPL = {'LP6','LP7','LPI17'};
PMC = {'LPI11','LPI12','LPI13'};
elecs1 = SPL;
elecs2 = PMC;

computePLVAll(sbj_name,project_name,block_names,dirs,elecs1,elecs2,'all','trials','stim','SpecDenseLF','condNames',[],[])
% computePLVAll(sbj_name,project_name,block_names,dirs,elecs1,elecs2,pairing,PLVdim,locktype,freq_band,column,conds,plv_params)

%% Phase-amplitude coupling

% phase_elecs = {'RPT1','RPG1','RPG2','RPG9','RPG10'};
% phase_elecs = {'RPT1','RPG2','RPG9'}; %S17_116

phase_elecs = {'LP6','LP7','LPS7','LPS8','LPI17','LPI11','LPI12','LP2','LP3','LP4','LPS1'}; %S14_69b


PAC = computePACAll(sbj_name,project_name,block_names,dirs,phase_elecs,[],[],'SpecDenseLF','stim','condNames',[],[]);

plotPAC(PAC,{'math','autobio'},'LP6',[])

%% PLV RT correlation
PLVRTCorrAll(sbj_name,project_name,block_names,dirs,elecs1,elecs2,'all','stim','condNotAfterMtn',[],[])

%% DONE PREPROCESSING. 
% Eventually replace globalVar to update dirs in case of working from an
% with an external hard drive
%UpdateGlobalVarDirs(sbj_name, project_name, block_name, dirs)

%% Branch 7 - Plotting
% plot individual trials (to visualize bad trials)
plot_params = genPlotParams(project_name,'timecourse');
plot_params.single_trial = true;
plot_params.noise_method = 'trials'; %'trials','timepts','none'
% plot_params.noise_fields_timepts = {'bad_epochs_HFO','bad_epochs_raw_HFspike'};
plot_params.noise_fields_trials = {'bad_epochs_HFO','bad_epochs_raw_HFspike'};
plot_params.textsize = 10;
PlotTrialAvgAll(sbj_name,project_name,block_names,dirs,[],'HFB','stim','condNames',[],plot_params,'Band')

% plot avg. HFB timecourse for each electrode separately
plot_params = genPlotParams(project_name,'timecourse');
plot_params.noise_method = 'trials'; %'trials','timepts','none'
plot_params.noise_fields_trials = {'bad_epochs_HFO','bad_epochs_raw_HFspike'};
PlotTrialAvgAll(sbj_name,project_name,block_names,dirs,[],'HFB','stim','condNames',[],plot_params,'Band')

% plot HFB timecourse, grouping multiple conds together
plot_params = genPlotParams(project_name,'timecourse');
plot_params.noise_method = 'trials'; %'trials','timepts','none'
plot_params.noise_fields_trials = {'bad_epochs_HFO','bad_epochs_raw_HFspike'};
PlotTrialAvgAll(sbj_name,project_name,block_names,dirs,[],'HFB','stim','condNames',{{'math','autobio'},{'math'}},plot_params,'Band')

% plot HFB timecourse for multiple elecs on same plot
plot_params = genPlotParams(project_name,'timecourse');
plot_params.noise_method = 'trials'; %'trials','timepts','none'
plot_params.noise_fields_trials = {'bad_epochs_HFO','bad_epochs_raw_HFspike'};
plot_params.multielec = true;
elecs = {'LP7','LPS8','LP4'}; %S14_69b
PlotTrialAvgAll(sbj_name,project_name,block_names,dirs,elecs,'HFB','stim','condNames',{'math'},plot_params,'Band')

% plot inter-trial phase coherence for each electrode
plot_params = genPlotParams(project_name,'ITPC');
plot_params.noise_method = 'trials'; %'trials','timepts','none'
plot_params.noise_fields_trials = {'bad_epochs_HFO','bad_epochs_raw_HFspike'};
PlotITPCAll(sbj_name,project_name,block_names,dirs,1,'Spec2','stim','condNames',[],plot_params)

% plot ERSP (event-related spectral perturbations) for each electrode
plot_params = genPlotParams(project_name,'ERSP');
plot_params.noise_method = 'trials'; %'trials','timepts','none'
plot_params.noise_fields_trials = {'bad_epochs_HFO','bad_epochs_raw_HFspike'};
elecs = {'LP7'};
PlotERSPAll(sbj_name,project_name,block_names,dirs,[],'SpecDenseLF','stim','condNames',[],plot_params)

% Number comparison
% load a given trialinfo
% load([dirs.result_root,'/',project_name,'/',sbj_name,'/',block_names{1},'/trialinfo_',block_names{1},'.mat'])
% conds_dist = unique(trialinfo.conds_num_lum_digit_dot_distance)
% conds_number_digit = conds_dist(contains(conds_dist, 'number_digit'));
% conds_number_dot = conds_dist(contains(conds_dist, 'number_dot'));
% conds_brightness_dot = conds_dist(contains(conds_dist, 'brightness_dot'));
% conds_brightness_digit= conds_dist(contains(conds_dist, 'brightness_digit'));


col = gray(4)
col = col*0.85

PlotTrialAvgAll(sbj_name,project_name,block_names,dirs,[],'HFB','stim','conds_num_lum_digit_dot_distance',conds_number_digit,col,'trials',[],x_lim)

% TODO: 
% Allow conds to be any kind of class, logical, str, cell, double, etc.
% Input baseline correction flag to have the option.
% Include the lines option

PlotERSPAll(sbj_name,project_name,block_names,dirs,[],'stim','condNames',[],'trials',[])
PlotERSPAll(sbj_name,project_name,block_names,dirs,[],'stim','conds_calc',[],'trials',[])

% TODO: Fix cbrewer 2

%% STATS
tag = 'stimlock_bl_corr';
[p,p_fdr,sig] = permutationStatsAll(sbj_name,project_name,block_names,dirs,elecs,tag,'condNames',{'math'},'HFB',[]);
%% Branch 8 - integrate brain and electrodes location MNI and native and other info
% Load and convert Freesurfer to Matlab
fsDir_local = '/Applications/freesurfer/subjects/fsaverage';
cortex = getcort(dirs);
coords = importCoordsFreesurfer(dirs);
elect_names = importElectNames(dirs);
V = importVolumes(dirs);

% Convert electrode coordinates from native to MNI space
[MNI_coords, elecNames, isLeft, avgVids, subVids] = sub2AvgBrainCustom([],dirs, fsDir_local);

% Plot brain and coordinates
% transform coords
% coords(:,1) = coords(:,1) + 5;
% coords(:,2) = coords(:,2) + 5;
% coords(:,3) = coords(:,3) - 5;

figureDim = [0 0 1 .4];
figure('units', 'normalized', 'outerposition', figureDim)

views = [1 2 4];
hemisphere = 'left';

% Plot electrodes as dots
for i = 1:length(views)
    subplot(1,length(views),i)
    ctmr_gauss_plot(cortex.(hemisphere),[0 0 0], 0, hemisphere(1), views(i))
    f1 = plot3(coords(:,1),coords(:,2),coords(:,3), '.', 'Color', 'b', 'MarkerSize', 40);
    alpha(0.5)

%     if i > 2
%         f1.Parent.OuterPosition(3) = f1.Parent.OuterPosition(3)/2;
%     else
%     end
end
light('Position',[1 0 0])


% Plot electrodes as text
views = [1 4];

for v = 1:length(views)
    subplot(1,length(views),v)
    ctmr_gauss_plot(cortex.(hemisphere),[0 0 0], 0, hemisphere(1), views(v))
    for i = 1:length(elecs)
        hold on
        text(coords(i,1),coords(i,2),coords(i,3), num2str(elecs(i)), 'FontSize', 20);
    end
    alpha(0.5)
end


% Plot two hemispheres
ctmr_gauss_plot(cortex.left,[0 0 0], 0, 'left', 1)
ctmr_gauss_plot(cortex.right,[0 0 0], 0, 'right', 1)
f1 = plot3(coords(:,1),coords(:,2),coords(:,3), '.', 'Color', 'k', 'MarkerSize', 40);
f1 = plot3(coords(e,1),coords(e,2),coords(e,3), '.', 'Color', 'r', 'MarkerSize', 40);
text(coords(e,1),coords(e,2),coords(e,3), num2str(elecs(e)), 'FontSize', 20);



%% Create subjVar
subjVar = [];
subjVar.cortex = cortex;
subjVar.V = V;
subjVar.elect_native = coords;
subjVar.elect_MNI = MNI_coords;
subjVar.elect_names = elect_names;
subjVar.demographics = GetDemographics(sbj_name, dirs);
save([dirs.original_data '/' sbj_name '/subjVar.mat' ], 'subjVar')

% demographics
% date of implantation
% birth data
% age
% gender
% handedness
% IQ full
% IQ verbal
% ressection?


%% Copy subjects
subjs_to_copy = {'S18_125'};
parfor i = 1:lenght(subjs_to_copy)
    CopySubject(subjs_to_copy{i}, dirs.psych_root, '/Volumes/LBCN8T/Stanford/data2/psychData', dirs.data_root, '/Volumes/LBCN8T/Stanford/data2/neuralData')
    UpdateGlobalVarDirs(subjs_to_copy{i}, project_name, block_names, dirs)
end
%% Medium-long term projects
% 1. Creat subfunctions of the EventIdentifier specific to each project
% 2. Stimuli identity to TTL

%% Concatenate all trials all channels
plot_params.blc = true;
data_all = ConcatenateAll(sbj_name,project_name,block_names,dirs,[],'HFB','stim', plot_params);



%% Behavioral analysis
% Load behavioral data
load()

datatype = 'HFB'
plot_params.blc = true
locktype = 'stim'
data_all.trialinfo = [];
for i = 1:length(block_names)
    bn = block_names {i};
    dir_in = [dirs.data_root,'/','HFB','Data/',sbj_name,'/',bn,'/EpochData/'];
    
    if plot_params.blc
        load(sprintf('%s/%siEEG_%slock_bl_corr_%s_%.2d.mat',dir_in,datatype,locktype,bn,1));
    else
        load(sprintf('%s/%siEEG_%slock_%s_%.2d.mat',dir_in,datatype,locktype,bn,1));
    end
    % concatenate trial info
    data_all.trialinfo = [data_all.trialinfo; data.trialinfo]; 
end

data_calc = data_all.trialinfo(data_all.trialinfo.isCalc == 1,:)
acc = sum(data_calc.Accuracy)/length(data_calc.Accuracy);
mean_rt = mean(data_calc.RT(data_calc.Accuracy == 1));
sd_rt = std(data_calc.RT(data_calc.Accuracy == 1));

boxplot(data_calc.RT(data_calc.Accuracy == 1), data_calc.OperandMin(data_calc.Accuracy == 1))
set(gca,'fontsize',20)
ylabel('RT (sec.)')
xlabel('Min operand')


%% MMR
data_calc = data_all.trialinfo(strcmp(data_all.trialinfo.condNames, 'math'),:);




