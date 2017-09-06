loadParameters;

load(fullfile(params.punctaSubvolumeDir,sprintf('%s_puncta_rois.mat',params.FILE_BASENAME)));

puncta_set_normed = zeros(size(puncta_set));

%The normalization method is now: 
%For each color in each expeirmental round,
%subtract the minimum pixel value, 
%then calculate + divide by the mean
for exp_idx = 1:params.NUM_ROUNDS
    clear chan_col
    for c = params.COLOR_VEC
        chan_col(:,c) = reshape(puncta_set(:,:,:,exp_idx,c,:),[],1);
    end
%     chan_col(:,2) = reshape(puncta_set(:,:,:,exp_idx,2,:),[],1);
%     chan_col(:,3) = reshape(puncta_set(:,:,:,exp_idx,4,:),[],1);
      
    %How many unique values do we see per channel? (only useful to check
    %for unintentional 8-bit data)
    
    figure;
    subplot(length(params.COLOR_VEC),1,1)
    for c = params.COLOR_VEC
        subplot(length(params.COLOR_VEC),1,c)
        h = histogram(chan_col(:,c),100);
        unique_vals_count = length(unique(chan_col(:,c)));
        title(sprintf('Exp %i: Histogram of Channel %i. Unique values %i',exp_idx,c, unique_vals_count));
    end
    
%     subplot(3,1,2)
%     h = histogram(chan_col(:,2),100);
%     unique_vals_count = length(unique(chan_col(:,2)));
%     title(sprintf('Exp %i: Histogram of Channel 2. Unique values %i',exp_idx, unique_vals_count));
%     
%     subplot(3,1,3)
%     
%     h = histogram(chan_col(:,3),100);
%     unique_vals_count = length(unique(chan_col(:,3)));
%     title(sprintf('Exp %i: Histogram of Channel 4. Unique values %i',exp_idx, unique_vals_count));
   
    %V6 was quantilenorm
%     cols_normed = quantilenorm(chan_col);
    %v7 is mean normed
    %v8 is subtracting the mean before dividing by the norm
    chan_col = chan_col - repmat(min(chan_col,[],1),size(chan_col,1),1);
    mean_vec = mean(chan_col,1);
    cols_normed = chan_col ./ repmat(mean_vec,size(chan_col,1),1);

    for c = params.COLOR_VEC
        puncta_set_normed(:,:,:,exp_idx,c,:) = reshape(cols_normed(:,c),squeeze(size(puncta_set(:,:,:,exp_idx,c,:))));
    end
%     puncta_set_normed(:,:,:,exp_idx,2,:) = reshape(cols_normed(:,2),squeeze(size(puncta_set(:,:,:,exp_idx,1,:))));
%     puncta_set_normed(:,:,:,exp_idx,4,:) = reshape(cols_normed(:,3),squeeze(size(puncta_set(:,:,:,exp_idx,1,:))));
exp_idx
end

transcripts = zeros(size(puncta_set_normed,6),params.NUM_ROUNDS);
transcripts_confidence = zeros(size(puncta_set_normed,6),params.NUM_ROUNDS);
puncta_ctr = 1;


for puncta_idx = 1:size(puncta_set_normed,6)
    
    answer_vector = zeros(params.NUM_ROUNDS,1);
    confidence_vector = zeros(params.NUM_ROUNDS,1);
    for exp_idx = 1:params.NUM_ROUNDS
        
        punctaset_perround = squeeze(puncta_set_normed(:,:,:,exp_idx,:,puncta_idx));
        
        max_intensity = max(max(max(max(punctaset_perround))))+1;
        min_intensity = min(min(min(min(punctaset_perround))));
        
        [max_chan, confidence] = chooseChannel(punctaset_perround,params.COLOR_VEC,params.DISTANCE_FROM_CENTER);
        answer_vector(exp_idx) = max_chan;
        confidence_vector(exp_idx) = confidence;
    end
    
    transcripts(puncta_ctr,:) = answer_vector;
    transcripts_confidence(puncta_ctr,:) = confidence_vector;
    pos(puncta_ctr,:) = [Y(puncta_idx),X(puncta_idx),Z(puncta_idx)];
    puncta_ctr = puncta_ctr +1;
    
    fprintf('Calling base puncta #%i out of %i \n',puncta_ctr, size(puncta_set_normed,6));
    
    
end

save(fullfile(params.punctaSubvolumeDir,'transcriptsv9_punctameannormed.mat'),'transcripts','transcripts_confidence','pos');

