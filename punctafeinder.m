
loadParameters;


%M is the mask
m = {};
%centroids are the location
centroids = {};

chan_strs = {'ch00','ch01SHIFT','ch02SHIFT','ch03SHIFT'};
for round_num = 1:params.NUM_ROUNDS
    
    for chan_num = 1:params.NUM_CHANNELS
        tic
        chan_str = chan_strs{chan_num};
        filename_in = fullfile(params.registeredImagesDir,sprintf('%s_round%.03i_%s.tif',params.FILE_BASENAME,round_num,chan_str));
        stack_in = load3DTif_uint16(filename_in);
        
        %Todo: trim the registration (not relevant in the crop)
        background = min(stack_in,[],3);
        toc
        tic
        stack_original = stack_in;
        stack_in = dog_filter(stack_in);
        
        %min project of 3D image
        back_dog = dog_filter2d(background);
        %avoding registration artifacts
        %2* is a magic number that just works
        back_dogmax = 2*max(max(back_dog(5:end-5,5:end-5,:))); % avoid weird edge effects
        
        fgnd_mask = zeros(size(stack_in));
        fgnd_mask(stack_in>back_dogmax) = 1; % use first slice to determine threshold for dog
        fgnd_mask = logical(fgnd_mask); % and get mask
        
        stack_in(~fgnd_mask) = 0; % thresholded using dog background
        
        
        %max project pxls
        %z = -Inf(size(stack_in));
        %z(fgnd_mask) = zscore(single(stack_original(fgnd_mask)));
        fgnd_cell{chan_num} = fgnd_mask;
        stack_cell{chan_num} = stack_in;
        %z_cell{chan_num} = z;
        % max project normalized stuff; after setting bkgd to 0
    end
    
    %logical OR all foregrounds together
    allmask = fgnd_cell{1} | fgnd_cell{2} | fgnd_cell{3} | fgnd_cell{4};
    
    %initializig the array of size of the 3d image
    z_cell{1} = -Inf(size(stack_in));
    z_cell{2} = -Inf(size(stack_in));
    z_cell{3} = -Inf(size(stack_in));
    z_cell{4} = -Inf(size(stack_in));
    
    %calculate the zscore of all the foreground pixels (done across channels),
    %done per channel
    z_cell{1}(allmask) = zscore(single(stack_cell{1}(allmask)));
    z_cell{2}(allmask) = zscore(single(stack_cell{2}(allmask)));
    z_cell{3}(allmask) = zscore(single(stack_cell{3}(allmask)));
    z_cell{4}(allmask) = zscore(single(stack_cell{4}(allmask)));
    
    %re-masking foreground, now used per channel.
    z_cell{1}(~fgnd_cell{1}) = -Inf;
    z_cell{2}(~fgnd_cell{2}) = -Inf;
    z_cell{3}(~fgnd_cell{3}) = -Inf;
    z_cell{4}(~fgnd_cell{4}) = -Inf;
    
    %Create a new mask per channel based on when a channel is the winner
    [m{1},m{2},m{3},m{4}] = maxprojmask(z_cell{1}, z_cell{2}, z_cell{3}, z_cell{4});
    
    for chan_num = 1:params.NUM_CHANNELS
        
        stack_in = stack_cell{chan_num};
        
        % max project
        
        %set nonlargest to 0
        stack_in(~m{chan_num}) = 0;
        neg_masked_image = -int32(stack_in);
        neg_masked_image(~stack_in) = inf;
        toc
        tic
        L = uint32(watershed(neg_masked_image));
        L(~stack_in) = 0;
        fprintf('wshed\n');
        
        toc
        candidate_puncta= regionprops(L, 'Centroid', 'PixelIdxList');
        indices_to_remove = [];
        for i= 1:length(candidate_puncta)
            if size(candidate_puncta(i).PixelIdxList,1)< params.PUNCTA_SIZE_THRESHOLD
                indices_to_remove = [indices_to_remove i];
            end
        end
        good_indices = 1:length(candidate_puncta);
        good_indices(indices_to_remove) = [];
        
        filtered_puncta = candidate_puncta(good_indices);
        fprintf('Round%i, Chan %i: removed %i candidate puncta for being too small\n',...
            round_num,chan_num,length(candidate_puncta)-length(filtered_puncta));
        
        
        centroids{round_num, chan_num} = filtered_puncta;
        
        output_img = zeros(size(stack_in));
        
        for i= 1:length(filtered_puncta)    
            %Set the pixel value to somethign non-zero
            output_img(filtered_puncta(i).PixelIdxList)=100;
        end
        
        filename_out = fullfile(params.punctaSubvolumeDir,sprintf('%s_round%.03i_%s_punta.tif',params.FILE_BASENAME,round_num,chan_strs{chan_num}));
        save3DTif_uint16(L,filename_out);
        
    end
    
    
end

%combine the centroid objects into a single set of centroids+pixels per
%round

puncta_centroids = cell(params.NUM_ROUNDS,1);
puncta_voxels = cell(params.NUM_ROUNDS,1);

for rnd_idx=1:params.NUM_ROUNDS
    num_puncta_per_round = 0;
    for c_idx = 1:params.NUM_CHANNELS
        num_puncta_per_round = num_puncta_per_round + numel(centroids{rnd_idx,c_idx});
    end
    
    %initialize the vectors for the particular round
    centroids_per_round = zeros(num_puncta_per_round,3);
    voxels_per_round = cell(num_puncta_per_round,1);
    
    ctr = 1;
    for c_idx = 1:params.NUM_CHANNELS
        round_objects = centroids{rnd_idx,c_idx};
        for r_idx = 1:size(round_objects,1)
            centroids_per_round(ctr,:) = round_objects(r_idx).Centroid;
            voxels_per_round{ctr} = round_objects(r_idx).PixelIdxList;
            ctr = ctr +1;
        end
    end
    
    puncta_centroids{rnd_idx} = centroids_per_round;
    puncta_voxels{rnd_idx} = voxels_per_round;
end


filename_centroids = fullfile(params.punctaSubvolumeDir,sprintf('%s_centroids+pixels.mat',params.FILE_BASENAME));
save(filename_centroids, 'puncta_centroids','puncta_voxels', '-v7.3');

