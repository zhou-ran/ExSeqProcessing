
fn = fullfile('/mp/nas1/share/ExSEQ/ExSeqAutoFrameA1/3_normalization/exseqautoframea1_round006_ch03SHIFT.tif');
len = 400;
img = load3DTif_uint16(fn);

N = 2
%keypts = zeros(N, 3);
load res_vect

keys = res_vect(1:N, :);

%sub2ind(size(img), keys(1,1), keys(1,2), keys(1,3));
%sub2ind(size(img), keys(2,1), keys(2,2), keys(2,3));

tic
sift_keys_cuda = calculate_3DSIFT_cuda(img, keys, false);
toc

tic
sift_keys = calculate_3DSIFT(img, keys, false);
toc

%load 3DSIFTkeys % loads old keys

%assert(isequal(new_keys, keys))

%start= 1;
%for i=1:N
    %keypts(i, 1) = start;
    %start = start + 120;
%end
%keypts

