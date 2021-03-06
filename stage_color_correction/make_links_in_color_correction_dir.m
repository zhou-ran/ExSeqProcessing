function ret = make_links_in_color_correction_dir()

    ret = true;

    loadParameters;

    src_dir = relpath(params.colorCorrectionImagesDir,params.deconvolutionImagesDir);
    old_dir = pwd;
    cd(params.colorCorrectionImagesDir);

    FILEROOT_NAME = sprintf('%s-downsample',params.FILE_BASENAME);

    for r_i = 1:params.NUM_ROUNDS
        src_filename = fullfile(src_dir,sprintf('%s_round%03i_%s.%s',FILEROOT_NAME,r_i,params.SHIFT_CHAN_STRS{1},params.IMAGE_EXT));
        if ~exist(src_filename,'file')
            fprintf('[ERROR] not exist source file: %s\n',src_filename);
            ret = false;
            continue
        end

        dst_filename = sprintf('./%s_round%03i_%s.%s',FILEROOT_NAME,r_i,params.SHIFT_CHAN_STRS{1},params.IMAGE_EXT);
        if ~exist(dst_filename,'file')
            fprintf('ln -s %s %s\n',src_filename,dst_filename);
            system(sprintf('ln -s %s %s',src_filename,dst_filename));
        end
    end
    

    cd(old_dir);
end

