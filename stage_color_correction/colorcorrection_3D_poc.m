function colorcorrection_3D_poc(roundnum)

loadParameters;


if isfield(params,'COLOR_CORRECTION_MAX_THREADS')
    maxNumCompThreads(params.COLOR_CORRECTION_MAX_THREADS);
end

if params.DO_DOWNSAMPLE
    FILEROOT_NAME = sprintf('%s-downsample',params.FILE_BASENAME);
else
    FILEROOT_NAME = sprintf('%s',params.FILE_BASENAME);
end


DIRECTORY = params.deconvolutionImagesDir;
OUTPUTDIR = params.colorCorrectionImagesDir;

fprintf('Starting processing of round %i\n',roundnum);
%Load all channels, normalize them, calculate the cross corr of
%channels 1-3 vs 4
tic; disp('load file 1');

if exist(fullfile(OUTPUTDIR,sprintf('%s_round%.03i_ch02SHIFT.%s',FILEROOT_NAME,roundnum,params.IMAGE_EXT)),'file' );
    fprintf('SEES ch02SHIFT file in the output directory. Skipping\n');
    return
end

try
    chan1 = load3DImage_uint16(fullfile(DIRECTORY,sprintf('%s_round%.03i_ch00.%s',FILEROOT_NAME,roundnum,params.IMAGE_EXT)));
catch
    fprintf('ERROR LOADING FILE: Is this a missing round?\n');
    return
end
toc
tic; disp('load file 2');
chan2 = load3DImage_uint16(fullfile(DIRECTORY,sprintf('%s_round%.03i_ch01.%s',FILEROOT_NAME,roundnum,params.IMAGE_EXT)));
toc
tic; disp('load file 3');
chan3 = load3DImage_uint16(fullfile(DIRECTORY,sprintf('%s_round%.03i_ch02.%s',FILEROOT_NAME,roundnum,params.IMAGE_EXT)));
toc
tic; disp('load file 4');
chan4 = load3DImage_uint16(fullfile(DIRECTORY,sprintf('%s_round%.03i_ch03.%s',FILEROOT_NAME,roundnum,params.IMAGE_EXT)));
toc

chan1_beads = chan1(:,:,params.BEAD_ZSTART :end);
chan2_beads = chan2(:,:,params.BEAD_ZSTART :end);
chan4_beads = chan4(:,:,params.BEAD_ZSTART :end);
clear chan1

tic; disp('POC 4');
chan4_offsets = phaseOnlyCorrelation(chan1_beads,chan4_beads,params.COLOR_OFFSETS3D);
toc
clear chan4_beads

size(params.COLOR_OFFSETS3D)
fprintf('Round %i: Offsets for chan%i: %i %i %i\n',roundnum,4,chan4_offsets(1),chan4_offsets(2),chan4_offsets(3));
tic; disp('translate 4');
chan4_shift = imtranslate3D(chan4,real(round(chan4_offsets)));
toc
clear chan4

tic; disp('save file 4');
save3DImage_uint16(chan4_shift,fullfile(OUTPUTDIR,sprintf('%s_round%.03i_ch03SHIFT.%s',FILEROOT_NAME,roundnum,params.IMAGE_EXT)));
toc

chan4_shift_beads = chan4_shift(:,:,params.BEAD_ZSTART :end);
tic; disp('POC 2');
chan2_offsets = phaseOnlyCorrelation(chan1_beads+chan4_shift_beads,chan2_beads,params.COLOR_OFFSETS3D);
toc
clear chan1_beads chan2_beads chan4_shift chan4_shift_beads

fprintf('Round %i: Offsets for chan%i: %i %i %i\n',roundnum,2,chan2_offsets(1),chan2_offsets(2),chan2_offsets(3));
tic; disp('translate 2');
chan2_shift = imtranslate3D(chan2,round(chan2_offsets));
toc

tic; disp('save file 2');
save3DImage_uint16(chan2_shift,fullfile(OUTPUTDIR,sprintf('%s_round%.03i_ch01SHIFT.%s',FILEROOT_NAME,roundnum,params.IMAGE_EXT)));
toc
clear chan2 chan2_shift

tic;
fprintf('quantilenorm_simple starting\n');

%data_cols_norm = quantilenorm_simple(data_cols);
use_tmp_files = true;
basename = sprintf('%s_round%03d',FILEROOT_NAME,roundnum);
ret = ...
    quantilenorm_cuda(params.tempDir,basename, { ...
        fullfile(DIRECTORY,sprintf('%s_round%.03i_ch00.%s'     ,FILEROOT_NAME,roundnum,params.IMAGE_EXT)), ...
        fullfile(OUTPUTDIR,sprintf('%s_round%.03i_ch01SHIFT.%s',FILEROOT_NAME,roundnum,params.IMAGE_EXT)), ...
        fullfile(DIRECTORY,sprintf('%s_round%.03i_ch02.%s'     ,FILEROOT_NAME,roundnum,params.IMAGE_EXT)), ...
        fullfile(OUTPUTDIR,sprintf('%s_round%.03i_ch03SHIFT.%s',FILEROOT_NAME,roundnum,params.IMAGE_EXT)) }, use_tmp_files);

chan1_norm_fname = ret{1};
chan2_norm_fname = ret{2};
chan3_norm_fname = ret{3};
chan4_norm_fname = ret{4};
image_size = ret{5};
image_height = image_size(1);
image_width  = image_size(2);
%num_slices   = image_size(3);

chan1_norm = load_binary_image(params.tempDir,chan1_norm_fname,image_height,image_width);
chan2_norm = load_binary_image(params.tempDir,chan2_norm_fname,image_height,image_width);
chan3_norm = load_binary_image(params.tempDir,chan3_norm_fname,image_height,image_width);
chan4_norm = load_binary_image(params.tempDir,chan4_norm_fname,image_height,image_width);

tic;
delete(fullfile(params.tempDir,chan1_norm_fname), ...
       fullfile(params.tempDir,chan2_norm_fname), ...
       fullfile(params.tempDir,chan3_norm_fname), ...
       fullfile(params.tempDir,chan4_norm_fname));
disp('delete the rest temp files'); toc;
fprintf('quantilenorm end\n');
toc

fixed_chans_norm = (chan1_norm + chan2_norm + chan4_norm)/3;

clear chan1_norm chan2_norm chan4_norm

%fixed_chans_norm_beads = fixed_chans_norm(:,:,params.BEAD_ZSTART:end);
%chan3_norm_beads = chan3_norm(:,:,params.BEAD_ZSTART:end);

tic; disp('POC 3');
chan3_offsets = phaseOnlyCorrelation(fixed_chans_norm,chan3_norm,params.COLOR_OFFSETS3D);
%chan3_offsets = phaseOnlyCorrelation(fixed_chans_norm_beads,chan3_norm_beads,offsets3D);
toc
clear chan3_norm fixed_chans_norm
fprintf('Round %i: Offsets for chan%i: %i %i %i\n',roundnum, 3,chan3_offsets(1),chan3_offsets(2),chan3_offsets(3));

tic; disp('translate 3');
chan3_shift = imtranslate3D(chan3,round(chan3_offsets));
toc
clear chan3

tic; disp('save file 3');
save3DImage_uint16(chan3_shift,fullfile(OUTPUTDIR,sprintf('%s_round%.03i_ch02SHIFT.%s',FILEROOT_NAME,roundnum,params.IMAGE_EXT)));
toc
clear chan3_shift

save(fullfile(OUTPUTDIR,sprintf('%s_round%.03i_colorcalcs.mat',FILEROOT_NAME,roundnum)),...
    'chan2_offsets',...
    'chan3_offsets',...
    'chan4_offsets');

end

