% Data loading a storage parameteres
params.deconvolutionImagesDir = '/home/dgoodwin/ExSeqProcessing/1_deconvolution';
params.colorCorrectionImagesDir = '/home/dgoodwin/ExSeqProcessing/1_deconvolution';
params.registeredImagesDir = '/home/dgoodwin/ExSeqProcessing/4_registration';% '/mp/nas0/ExSeq/AutoSeqHippocampusOrig/4_registration';
params.punctaSubvolumeDir = '/home/dgoodwin/ExSeqProcessing/5_puncta-extraction';
params.transcriptResultsDir = '/home/dgoodwin/ExSeqProcessing/6_transcripts';

params.FILE_BASENAME = 'exseqautoframe7';

%Experimental parameters
params.REFERENCE_ROUND_WARP=5;
params.REFERENCE_ROUND_PUNCTA = 5;
params.NUM_ROUNDS = 20;
params.NUM_CHANNELS = 4;
params.PUNCTA_SIZE = 10; %Defines the cubic region around each puncta

%RajLab filtering parameters:
params.THRESHOLD = 17; %Number of rouds to agree on 
params.EPSILON_TARGET = 4; %Radius of neighborhood for puncta to agree across rounds

%Base calling parameters
params.COLOR_VEC = [1,2,3,4]; %Which channels are we comparing? (in case of empty chan)
params.DISTANCE_FROM_CENTER = 2.5; %how far from the center of the puncta subvol?

params.THRESHOLD_EXPRESSION = 15; %If a transcript shows up fewer than this it's probably noise 
params.NUM_BUCKETS = 500; %For stastical analysis
params.THRESHOLD_AGREEMENT_CHOSEN = 10; %how many rounds should the intensity method agree with the probabilistic cleanup?
params.THRESHOLD_MARGIN = 0;

%Reporting directories
params.reportingDir = '/home/dgoodwin/ExSeqProcessing/logs/imgs';
