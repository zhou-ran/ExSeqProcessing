#include <iostream>
#include <future>

#include <thrust/copy.h>
#include <thrust/sort.h>
#include <thrust/execution_policy.h>
#include <thrust/replace.h>
#include <thrust/functional.h>
#include <thrust/iterator/counting_iterator.h>

#include <cuda_runtime.h>
/*#include <helper_cuda.h>*/
#include <cmath>
/*#include <numeric> //std::inner_product*/

#include "sift.h"
#include "matrix_helper.h"
#include "cuda_timer.h"

#include "spdlog/spdlog.h"

namespace cudautils {

struct isnan_test {
    __host__ __device__ bool operator() (const float a) const {
        return isnan(a);
    }
};

// column major order index into the descriptor vector
// note the descriptor vector length is determined by 
// sift_params.IndexSize ^ 3 * sift_params.nFaces
// this is why i, j, and k are dimensions of stride sift_params.IndexSize
__device__
int bin_sub2ind(int i, int j, int k, int l, const cudautils::SiftParams sift_params) {
    return l + sift_params.nFaces * (k + j * pow(sift_params.IndexSize, 1) + i
            * pow(sift_params.IndexSize, 2));
}

__device__
void place_in_index(double* index, double mag, int i, int j, int k, 
        double* yy, int* ix, const cudautils::SiftParams sift_params) {

    double tmpsum = 0.0;
    int bin_index;
    if (sift_params.Smooth_Flag) {
        for (int tessel=0; tessel < sift_params.Tessel_thresh; tessel++) {
            tmpsum += pow(yy[tessel], sift_params.Smooth_Var);
        }

        // Add three nearest tesselation faces
        for (int ii=0; ii<sift_params.Tessel_thresh; ii++) {
            bin_index = bin_sub2ind(i, j, k, ix[ii], sift_params);
            if (bin_index >= sift_params.descriptor_len)  {
                printf("Error: exiting all threads in %s at line %s place_in_index()", __FILE__, __LINE__ );
                asm("trap;");
            }
#ifdef DEBUG_OUTPUT
            /*printf("i%d j%d k%d ix[ii]%d bin_index%d yy[ii]%f\n", i, j, k,*/
                    /*ix[ii], bin_index, yy[ii]);*/
            /*printf("\tbin_index[%d]+=%.3f",bin_index, mag * pow(yy[ii], sift_params.Smooth_Var ) / tmpsum);*/
#endif
            index[bin_index] +=  mag * pow(yy[ii], sift_params.Smooth_Var ) / tmpsum;
        }
    } else {
        bin_index = bin_sub2ind(i, j, k, ix[0], sift_params);
        index[bin_index] += mag;
    }
#ifdef DEBUG_OUTPUT
    /*for (int i=0; i < sift_params.descriptor_len; i++) {*/
        /*if (index[i] != 0.0) {*/
            /*printf("\tindex[%d]=%.3f",i, index[i]);*/
        /*}*/
    /*}*/
#endif
    return;
}

__device__
double dot_product(double* first, double* second, int N) {
    double sum = 0.0;
    for (int i=0; i < N; i++) {
        sum += first[i] * second[i];
    }
    return sum;
}

// assumes r,c,s lie within accessible image boundaries
__device__
double get_grad_ori_vector(double* image, unsigned int idx, unsigned int
        x_stride, unsigned int y_stride, double vect[3], double* yy, int* ix,
        const cudautils::SiftParams sift_params, double* device_centers) {

    double xgrad = image[idx + x_stride] - image[idx - x_stride];
    //FIXME is this correct direction?
    double ygrad = image[idx - 1] - image[idx + 1];
    double zgrad = image[idx + x_stride * y_stride] - image[idx - x_stride * y_stride];

    /*printf("get_grad_ori_vector image[idx -1] %f image[idx+1] %f\n", image[idx - 1], image[idx + 1]);*/
    /*printf("XXX\txgrad %f y %f z %f\n", xgrad, ygrad, zgrad);*/

    double mag = sqrt(xgrad * xgrad + ygrad * ygrad + zgrad * zgrad);

    xgrad /= mag;
    ygrad /= mag;
    zgrad /= mag;

    if (mag !=0) {
        vect[0] = xgrad;
        vect[1] = ygrad;
        vect[2] = zgrad;
    } 

    //Find the nearest tesselation face indices
    //FIXME cublasSgemm() higher performance
    int dims = 3;
    int N = sift_params.fv_centers_len / dims;
    /*double* corr_array;*/
    for (int i=0; i < N; i++) {
        yy[i] = dot_product(&(device_centers[i * dims]),
                vect, dims);
    }
    thrust::sequence(thrust::device, ix, ix + N);
    // descending order by ori_hist
    thrust::sort_by_key(thrust::device, ix, ix + N, yy, thrust::greater<int>());

    /*[>//FIXME remove<]*/
    /*for (int i=0; i < 3; i++) {*/
        /*if (yy[i] != 0.0) {*/
            /*printf("XXX    yy[%d]=%.3f", i, yy[i]);*/
        /*}*/
        /*printf("\n");*/
    /*}*/

    return mag;
}

/*r, c, s is the pixel index (x, y, z dimensions respect.) in the image within the radius of the */
/*keypoint before clamped*/
/*For each pixel, take a neighborhhod of xyradius and tiradius,*/
/*bin it down to the sift_params.IndexSize dimensions*/
/*thus, i_indx, j_indx, s_indx represent the binned index within the radius of the keypoint*/
__device__
void add_sample(double* index, double* image, double distsq, unsigned int
        idx, unsigned int x_stride, unsigned int y_stride, int i_bin, int j_bin, int k_bin, 
        const cudautils::SiftParams sift_params, double* device_centers) {

    double sigma = sift_params.SigmaScaled;
    double weight = exp(-(distsq / (2.0 * sigma * sigma)));

    double vect[3] = {1.0, 0.0, 0.0};

    // default fv_centers_len 240; 960 bytes
    int* ix = (int *) malloc(sift_params.fv_centers_len*sizeof(int));
    cudaCheckPtr(ix);

    // default fv_centers_len 240; 1920 bytes
    double *yy = (double*) malloc(sift_params.fv_centers_len * sizeof(double));
    cudaCheckPtr(yy);

    // gradient and orientation vectors calculated from 3D halo/neighboring
    // pixels
    double mag = get_grad_ori_vector(image, idx, x_stride, y_stride, vect, yy, ix, sift_params, 
            device_centers);
    mag *= weight; // scale magnitude by gaussian 

    place_in_index(index, mag, i_bin, j_bin, k_bin, yy, ix, sift_params);
    free(ix);
    free(yy);
    return;
}


// floor quotient, add 1
// clamp bin idx to IndexSize
__device__
inline int get_bin_idx(int orig, int radius, int IndexSize) {
    int idx = (int) 1 + ((orig + radius) / (2.0 * radius / IndexSize));
    if (idx >= IndexSize) // clamp to IndexSize
        idx = IndexSize - 1;
    return idx;
}

__device__
double* key_sample(const cudautils::SiftParams sift_params, 
        cudautils::Keypoint key, double* image, unsigned int idx,
        unsigned int x_stride, unsigned int y_stride, 
        double* device_centers) {

    double xySpacing = (double) sift_params.xyScale * sift_params.MagFactor;
    double tSpacing = (double) sift_params.tScale * sift_params.MagFactor;

    int xyiradius = rint(1.414 * xySpacing * (sift_params.IndexSize + 1) / 2.0);
    int tiradius = rint(1.414 * tSpacing * (sift_params.IndexSize + 1) / 2.0);

    int N = sift_params.descriptor_len;

    // default N=640; 5120 bytes
    double* index = (double*) malloc(N * sizeof(double));
    cudaCheckPtr(index);
    memset(index, 0.0, N * sizeof(double));

    // Surrounding radius of pixels are binned for computation 
    // according to sift_params.IndexSize
    int r, c, t, i_bin, j_bin, k_bin;
    double distsq;
    for (int i = -xyiradius; i <= xyiradius; i++) {
        for (int j = -xyiradius; j <= xyiradius; j++) {
            for (int k = -tiradius; k <= tiradius; k++) {

                // FIXME check for CUDA pow function
                distsq = (double) pow(i,2) + pow(j,2) + pow(k,2);

                // Find bin idx
                // FIXME check correct
                i_bin = get_bin_idx(i, xyiradius, sift_params.IndexSize);
                j_bin = get_bin_idx(j, xyiradius, sift_params.IndexSize);
                k_bin = get_bin_idx(k, tiradius, sift_params.IndexSize);
                
                // Find original image pixel idx
                r = key.x + i;
                c = key.y + j;
                t = key.z + k;

                // FIXME does this collide with GPU splitting?
                // only add if within image range
                if (!(r < 0  ||  r >= sift_params.image_size0 ||
                        c < 0  ||  c >= sift_params.image_size1
                        || t < 0 || t >= sift_params.image_size2)) {

                    add_sample(index, image, distsq, idx, x_stride, y_stride,
                            i_bin, j_bin, k_bin, sift_params,
                            device_centers);
                }
            }
        }
    }

    return index;
}

__device__
double* build_ori_hists(int x, int y, int z, unsigned int idx, unsigned int
        x_stride, unsigned int y_stride, int radius, double* image, 
        const cudautils::SiftParams sift_params, double* device_centers) {

    // default nFaces=80; 640 bytes
    double* ori_hist = (double*) malloc(sift_params.nFaces * sizeof(double));
    cudaCheckPtr(ori_hist);
    memset(ori_hist, 0.0, sift_params.nFaces * sizeof(double));
    /*for (int i=0; i < sift_params.nFaces; i++) {*/
        /*ori_hist[i] = 0.0;*/
    /*}*/
    /*double* ori_hist = (double*) calloc(sift_params.nFaces,sizeof(double));*/

    double mag;
    double vect[3] = {1.0, 0.0, 0.0};

    // default fv_centers_len 80 * 3 (3D) = 240; 960 bytes
    int* ix = (int*) malloc(sift_params.fv_centers_len*sizeof(int));
    cudaCheckPtr(ix);

    // default fv_centers_len 240; 1920 bytes
    double *yy = (double*) malloc(sift_params.fv_centers_len * sizeof(double));
    cudaCheckPtr(yy);

    int r, c, t;
    for (int i = -radius; i <= radius; i++) {
        for (int j = -radius; j <= radius; j++) {
            for (int k = -radius; k <= radius; k++) {
                // Find original image pixel idx
                r = x + i;
                c = y + j;
                t = z + k;

                // only add if within image range
                if (!(r < 0  ||  r >= sift_params.image_size0 ||
                        c < 0  ||  c >= sift_params.image_size1
                        || t < 0 || t >= sift_params.image_size2)) {
                    /*gradient and orientation vectors calculated from 3D halo/neighboring pixels*/
                    mag = get_grad_ori_vector(image, idx, x_stride, y_stride,
                            vect, yy, ix, sift_params, device_centers);
                    ori_hist[ix[0]] += mag;
                }
            }
        }
    }
    free(ix);
    free(yy);
    return ori_hist;
}

__device__
void normalize_vec(double* vec, int len) {

    double sqlen = 0.0;
    for (int i=0; i < len; i++) {
        sqlen += vec[i] * vec[i];
    }

    double fac = 1.0 / sqrt(sqlen);
    for (int i=0; i < len; i++) {
        vec[i] = vec[i] * fac;
    }
    return;
}

__device__
cudautils::Keypoint make_keypoint_sample(cudautils::Keypoint key, double*
        image, const cudautils::SiftParams sift_params, unsigned int thread_idx, unsigned int idx,
        unsigned int x_stride, unsigned int y_stride,
        uint8_t * descriptors, double* device_centers) {

    bool changed = false;

    //FIXME make sure vec is in column order
    double* vec = key_sample(sift_params, key, image, idx, x_stride, y_stride, device_centers);

    int N = sift_params.descriptor_len;

    normalize_vec(vec, N);

    for (int i=0; i < N; i++) {
        if (vec[i] > sift_params.MaxIndexVal) {
            vec[i] = sift_params.MaxIndexVal;
            changed = true;
        }
    }

    if (changed) {
        normalize_vec(vec, N);
    }

    int intval;
    for (int i=0; i < N; i++) {
        intval = rint(512.0 * vec[i]);
        if (intval != 0) {
            /*printf("intval%d", intval);*/
        }
        //FIXME cuda function for min?
        descriptors[thread_idx * sift_params.descriptor_len + i] =  min((uint8_t) 255, (uint8_t) intval);
    }
    free(vec);
    return key;
}

__device__
cudautils::Keypoint make_keypoint(double* image, int x, int y, int z,
        unsigned int thread_idx, unsigned int idx, unsigned int x_stride, unsigned int y_stride,
        const cudautils::SiftParams sift_params,
        uint8_t * descriptors, double* device_centers) {
    cudautils::Keypoint key;
    key.x = x;
    key.y = y;
    key.z = z;

    return make_keypoint_sample(key, image, sift_params, thread_idx, idx,
            x_stride, y_stride, descriptors, device_centers);
}

/* Main function of 3DSIFT Program from http://www.cs.ucf.edu/~pscovann/
Inputs:
image - a 3 dimensional matrix of double
xyScale and tScale - affects both the scale and the resolution, these are
usually set to 1 and scaling is done before calling this function
x, y, and z - the location of the center of the keypoint where a descriptor is requested

Outputs:
keypoint - the descriptor, varies in size depending on values in LoadParams.m
reRun - a flag (0 or 1) which is set if the data at (x,y,z) is not
descriptive enough for a good keypoint
*/
__global__
void create_descriptor(
        unsigned int x_stride,
        unsigned int y_stride,
        unsigned int x_sub_start,
        unsigned int y_sub_start,
        unsigned int dw,
        unsigned int map_idx_size,
        unsigned int *map_idx,
        int8_t *map,
        double *image,
        const cudautils::SiftParams sift_params, 
        double* device_centers,
        uint8_t *descriptors) {

    // thread per keypoint in this substream
    unsigned int thread_idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (thread_idx >= map_idx_size) return;
    // map_idx holds the relevant image idxs only for the substream
    // map_idx_size matchs total # of threads
    // idx describes the linear index for current GPUs section of the image and corresponding map
    unsigned int idx = map_idx[thread_idx];
    /*printf("create_descriptor image[idx -1] %f image[idx+1] %f\n", image[idx - 1], image[idx + 1]);*/

    // column-major order since image is from matlab
    int x, y, z;
    unsigned int padding_x;
    unsigned int padding_y;
    unsigned int padding_z;
    ind2sub(x_stride, y_stride, idx, padding_x, padding_y, padding_z);
    // correct for dw_ padding, 0-indexed for checking boundaries
    x = x_sub_start + padding_x - dw;
    y = y_sub_start + padding_y - dw;
    z = padding_z - dw;
    
    if (sift_params.TwoPeak_Flag) {
        int radius = rint(sift_params.xyScale * 3.0);

        int ori_hist_len = sift_params.nFaces; //default 80
        int* ix = (int*) malloc(ori_hist_len*sizeof(int)); // default 320 bytes 
        cudaCheckPtr(ix);

        thrust::sequence(thrust::device, ix, ix + ori_hist_len);
        double* ori_hist = build_ori_hists(x, y, z, idx, x_stride, y_stride,
                radius, image, sift_params, device_centers);
        // descending order by ori_hist
        thrust::sort_by_key(thrust::device, ix, ix + ori_hist_len, ori_hist, thrust::greater<int>());
            
        int dims = 3;
        float thresh = .9;
        if ( 
            (dot_product(&(device_centers[dims * ix[0]]),
                &(device_centers[dims * ix[1]]),
                dims) > thresh) &&
            (dot_product(&(device_centers[dims * ix[0]]),
                &(device_centers[dims * ix[2]]), dims) > thresh)) {
            // FIXME remove this since memory is never accessed
            /*memset(&(descriptors[idx]), 0, sift_params.descriptor_len * sizeof(uint8_t));*/
            // mark this keypoint as null in map
            map_idx[thread_idx] = nan("");
            // FIXME print in final version
            /*printf("Removed keypoint from thread: %u, desc index: %u, x:%d y:%d z:%d\n", thread_idx, idx, x, y, z);*/
            return ;
        }

        free(ix);
        free(ori_hist);
    }

    cudautils::Keypoint key = make_keypoint(image, x, y, z, thread_idx, idx, x_stride, y_stride, sift_params,
            descriptors, device_centers);

    return;
}

/*Define the constructor for the SIFT class*/
/*See the class Sift definition in sift.h*/
Sift::Sift(
        const unsigned int x_size,
        const unsigned int y_size,
        const unsigned int z_size,
        const unsigned int x_sub_size,
        const unsigned int y_sub_size,
        const unsigned int dx,
        const unsigned int dy,
        const unsigned int dw,
        const unsigned int num_gpus,
        const unsigned int num_streams,
        const cudautils::SiftParams sift_params,
        const double* fv_centers)
    : x_size_(x_size), y_size_(y_size), z_size_(z_size),
        x_sub_size_(x_sub_size), y_sub_size_(y_sub_size),
        dx_(dx), dy_(dy), dw_(dw),
        num_gpus_(num_gpus), num_streams_(num_streams),
        sift_params_(sift_params),
        fv_centers_(fv_centers),
        subdom_data_(num_gpus) {

    logger_ = spdlog::get("console");
    if (! logger_) {
        logger_ = spdlog::stdout_logger_mt("console");
    }
#ifdef DEBUG_OUTPUT
    spdlog::set_level(spdlog::level::debug);
#else
    spdlog::set_level(spdlog::level::info);
#endif

    size_t log_q_size = 4096;
    spdlog::set_async_mode(log_q_size);

    num_x_sub_ = get_num_blocks(x_size_, x_sub_size_);
    num_y_sub_ = get_num_blocks(y_size_, y_sub_size_);

    x_sub_stride_ = x_sub_size_ + 2 * dw_;
    y_sub_stride_ = y_sub_size_ + 2 * dw_;

    dx_stride_ = dx_ + 2 * dw_;
    dy_stride_ = dy_ + 2 * dw_;
    z_stride_ = z_size_ + 2 * dw_;
#ifdef DEBUG_OUTPUT
    logger_->info("x_size={}, x_sub_size={}, num_x_sub={}, x_sub_stride={}, dx={}, dx_stride={}",
            x_size_, x_sub_size_, num_x_sub_, x_sub_stride_, dx_, dx_stride_);
    logger_->info("y_size={}, y_sub_size={}, num_y_sub={}, y_sub_stride={}, dy={}, dy_stride={}",
            y_size_, y_sub_size_, num_y_sub_, y_sub_stride_, dy_, dy_stride_);
    logger_->info("z_size={}, dw={}, z_stride={}", z_size_, dw_, z_stride_);
#endif


    dom_data_ = std::make_shared<DomainDataOnHost>(x_size_, y_size_, z_size_);

    for (unsigned int i = 0; i < num_gpus_; i++) {
        cudaSetDevice(i);

        subdom_data_[i] = std::make_shared<SubDomainDataOnGPU>(x_sub_stride_, y_sub_stride_, z_stride_, num_streams_);

        for (unsigned int j = 0; j < num_streams_; j++) {
            subdom_data_[i]->stream_data[j] = std::make_shared<SubDomainDataOnStream>(dx_stride_, dy_stride_, z_stride_);

            cudaStreamCreate(&subdom_data_[i]->stream_data[j]->stream);
        }
    }
    cudaSetDevice(0);


    unsigned int idx_gpu = 0;
    for (unsigned int y_sub_i = 0; y_sub_i < num_y_sub_; y_sub_i++) {
        for (unsigned int x_sub_i = 0; x_sub_i < num_x_sub_; x_sub_i++) {
            subdom_data_[idx_gpu]->x_sub_i_list.push_back(x_sub_i);
            subdom_data_[idx_gpu]->y_sub_i_list.push_back(y_sub_i);

            idx_gpu++;
            if (idx_gpu == num_gpus) {
                idx_gpu = 0;
            }
        }
    }

}

Sift::~Sift() {
    for (unsigned int i = 0; i < num_gpus_; i++) {
        for (unsigned int j = 0; j < num_streams_; j++) {
            cudaStreamDestroy(subdom_data_[i]->stream_data[j]->stream);
        }
    }

    //logger_->flush();
}

void Sift::setImage(const double *img)
{
    thrust::copy(img, img + (x_size_ * y_size_ * z_size_), dom_data_->h_image);
}

void Sift::setImage(const std::vector<double>& img)
{
    assert((x_size_ * y_size_ * z_size_) == img.size());

    thrust::copy(img.begin(), img.end(), dom_data_->h_image);

    //FIXME delete this
    /*printf("setImage\n");*/
    /*fflush(stdout);*/
    /*for (int i=0; i < 100; i++) {*/
        /*[>if (dom_data_->h_image[i] != 0.0) {<]*/
        /*printf("setImage h_image[%d]: %f\n", i, dom_data_->h_image[i]);*/
        /*printf("setImage img[%d]: %f\n", i, img[i]);*/
        /*fflush(stdout);*/
        /*[>}<]*/
    /*}*/
}

void Sift::setMapToBeInterpolated(const int8_t *map)
{
    thrust::copy(map, map + (x_size_ * y_size_ * z_size_), dom_data_->h_map);
}

void Sift::setMapToBeInterpolated(const std::vector<int8_t>& map)
{
    assert((x_size_ * y_size_ * z_size_) == map.size());

    thrust::copy(map.begin(), map.end(), dom_data_->h_map);
}

void Sift::getKeystore(cudautils::Keypoint_store *keystore)
{
    keystore->len = dom_data_->keystore->len;
    keystore->buf = (cudautils::Keypoint*) malloc(keystore->len * sizeof(cudautils::Keypoint));
    thrust::copy(dom_data_->keystore->buf, dom_data_->keystore->buf + dom_data_->keystore->len, keystore->buf);
}


void Sift::getImage(double *img)
{
    thrust::copy(dom_data_->h_image, dom_data_->h_image + x_size_ * y_size_ * z_size_, img);
}

void Sift::getImage(std::vector<double>& img)
{
    thrust::copy(dom_data_->h_image, dom_data_->h_image + x_size_ * y_size_ * z_size_, img.begin());
}


int Sift::getNumOfGPUTasks(const int gpu_id) {
    return subdom_data_[gpu_id]->x_sub_i_list.size();
}

int Sift::getNumOfStreamTasks(
        const int gpu_id,
        const int stream_id) {
    return 1;
}

void Sift::runOnGPU(
        const int gpu_id,
        const unsigned int gpu_task_id) {

    cudaSafeCall(cudaSetDevice(gpu_id));

    std::shared_ptr<SubDomainDataOnGPU> subdom_data = subdom_data_[gpu_id];
    std::shared_ptr<SubDomainDataOnStream> stream_data0 = subdom_data->stream_data[0];

    unsigned int x_sub_i = subdom_data->x_sub_i_list[gpu_task_id];
    unsigned int y_sub_i = subdom_data->y_sub_i_list[gpu_task_id];
#ifdef DEBUG_OUTPUT
    CudaTimer timer;
    logger_->info("===== gpu_id={} x_sub_i={} y_sub_i={}", gpu_id, x_sub_i, y_sub_i);
#endif

    // setting the heap memory must be performed before calling malloc in any kernel
    size_t heap_size = pow(2, 29); // 2 GB supports about 100,000 kypts for processing
    cudaSafeCall(cudaDeviceSetLimit(cudaLimitMallocHeapSize, heap_size));

#ifdef DEBUG_OUTPUT
    logger_->debug("GPU heap size={}", heap_size);
#endif

    unsigned int x_sub_start = x_sub_i * x_sub_size_;
    unsigned int y_sub_start = y_sub_i * y_sub_size_;
    // clamp delta to end value 
    unsigned int x_sub_delta = get_delta(x_size_, x_sub_i, x_sub_size_);
    unsigned int y_sub_delta = get_delta(y_size_, y_sub_i, y_sub_size_);
    // only add in pad factor at first
    unsigned int base_x_sub  = (x_sub_i > 0 ? 0 : dw_);
    unsigned int base_y_sub  = (y_sub_i > 0 ? 0 : dw_);

    // subtract pad factor after first
    unsigned int padding_x_sub_start = x_sub_start - (x_sub_i > 0 ? dw_ : 0);
    unsigned int padding_y_sub_start = y_sub_start - (y_sub_i > 0 ? dw_ : 0);
    unsigned int padding_x_sub_delta = x_sub_delta + (x_sub_i > 0 ? dw_ : 0) + (x_sub_i < num_x_sub_ - 1 ? dw_ : 0);
    unsigned int padding_y_sub_delta = y_sub_delta + (y_sub_i > 0 ? dw_ : 0) + (y_sub_i < num_y_sub_ - 1 ? dw_ : 0);

    // per GPU padded image size
    size_t padded_sub_volume_size = x_sub_stride_ * y_sub_stride_ * z_stride_;

#ifdef DEBUG_OUTPUT
    unsigned int x_sub_end = x_sub_start + x_sub_delta;
    unsigned int y_sub_end = y_sub_start + y_sub_delta;
    logger_->debug("x_sub=({},{},{}) y_sub=({},{},{})", x_sub_start, x_sub_delta, x_sub_end, y_sub_start, y_sub_delta, y_sub_end);
    logger_->debug("base_x_sub={},base_y_sub={}", base_x_sub, base_y_sub);

#ifdef DEBUG_OUTPUT_MATRIX
    // print the x, y, z image / map coordinates of the selected keypoints
    if (gpu_id == 0)  { // don't repeat this for every GPU
        for (long long idx=0; idx < x_size_ * y_size_ * z_size_; idx++) {
            if (! dom_data_->h_map[idx]) {
                unsigned int x;
                unsigned int y;
                unsigned int z;
                ind2sub(x_size_, y_size_, idx, x, y, z);

                logger_->info("h_map 0's: idx={}, x={}, y={}, z={}",
                        idx, x, y, z);
            }
        }
    }
#endif
#endif

    // allocate the per GPU padded map and image
    int8_t *padded_sub_map;
    double *padded_sub_image;
    cudaSafeCall(cudaHostAlloc(&padded_sub_map, padded_sub_volume_size *
                sizeof(int8_t), cudaHostAllocPortable));
        cudaCheckError();
    cudaSafeCall(cudaHostAlloc(&padded_sub_image, padded_sub_volume_size *
                sizeof(double), cudaHostAllocPortable));
        cudaCheckError();

    // First set all values to holder value -1
    thrust::fill(padded_sub_map, padded_sub_map + padded_sub_volume_size, -1);

    for (unsigned int k = 0; k < z_size_; k++) {
        for (unsigned int j = 0; j < padding_y_sub_delta; j++) {
            // get row-major / c-order linear index according orig. dim [x_size, y_size, z_size]
            size_t src_idx = dom_data_->sub2ind(padding_x_sub_start, padding_y_sub_start + j, k);
            size_t dst_idx = subdom_data->pad_sub2ind(base_x_sub, base_y_sub + j, dw_ + k);

            int8_t* src_map_begin = &(dom_data_->h_map[src_idx]);
            int8_t* dst_map_begin = &(padded_sub_map[dst_idx]);
            // note this assumes the rows to be contiguous in memory (row-order / c-order)
            thrust::copy(src_map_begin, src_map_begin + padding_x_sub_delta, dst_map_begin);

            double* src_image_begin = &(dom_data_->h_image[src_idx]);
            double* dst_image_begin = &(padded_sub_image[dst_idx]);
            thrust::copy(src_image_begin, src_image_begin + padding_x_sub_delta, dst_image_begin);
        }
    }
    
#ifdef DEBUG_OUTPUT_MATRIX

    //FIXME place this back in DEBUG_OUTPUT_MATRIX above
    // print the x, y, z in padded image / map coordinates of the selected keypoints
    for (long long i=0; i < padded_sub_volume_size; i++) {
        if (!padded_sub_map[i]) {
            unsigned int padding_x;
            unsigned int padding_y;
            unsigned int padding_z;
            ind2sub(x_sub_stride_, y_sub_stride_, i, padding_x, padding_y, padding_z);
            // correct for dw_ padding, matlab is 1-indexed
            unsigned int x = x_sub_start + padding_x - dw_ + 1;
            unsigned int y = y_sub_start + padding_y - dw_ + 1;
            unsigned int z = padding_z - dw_ + 1;

            logger_->info("padded_sub_map 0's (matlab 1-indexed): idx={}, x={}, y={}, z={}",
                    i, x, y, z);
        }
    }

#endif

    thrust::fill(thrust::device, subdom_data->padded_image, subdom_data->padded_image + padded_sub_volume_size, 0.0);

    cudaSafeCall(cudaMemcpyAsync(
            subdom_data->padded_image,
            padded_sub_image,
            padded_sub_volume_size * sizeof(double),
            cudaMemcpyHostToDevice, stream_data0->stream));

#ifdef DEBUG_OUTPUT
    cudaSafeCall(cudaStreamSynchronize(stream_data0->stream));
    logger_->info("transfer image data {}", timer.get_laptime());

#ifdef DEBUG_OUTPUT_MATRIX
    logger_->info("===== dev image");
    print_matrix3d(logger_, x_size_, y_size_, 0, 0, 0, x_size_, y_size_, z_size_, dom_data_->h_image);
    print_matrix3d_dev(logger_, x_sub_stride_, y_sub_stride_, z_stride_, 0, 0, 0, x_sub_stride_, y_sub_stride_, z_stride_, subdom_data->padded_image);
#endif

    timer.reset();
#endif

    cudaSafeCall(cudaMemcpyAsync(
            subdom_data->padded_map,
            padded_sub_map,
            padded_sub_volume_size * sizeof(int8_t),
            cudaMemcpyHostToDevice, stream_data0->stream));

#ifdef DEBUG_OUTPUT
    cudaSafeCall(cudaStreamSynchronize(stream_data0->stream));
    logger_->info("transfer map data {}", timer.get_laptime());

#ifdef DEBUG_OUTPUT_MATRIX
    logger_->debug("===== dev map");
    print_matrix3d(logger_, x_size_, y_size_, 0, 0, 0, x_size_, y_size_, z_size_, dom_data_->h_map);
    print_matrix3d_dev(logger_, x_sub_stride_, y_sub_stride_, z_stride_, 0, 0, 0, x_sub_stride_, y_sub_stride_, z_stride_, subdom_data->padded_map);
#endif

    timer.reset();
#endif

    // clear previous result to zero
    thrust::fill(thrust::device, subdom_data->padded_map_idx, subdom_data->padded_map_idx + padded_sub_volume_size, 0.0);

    /*Note: padded_sub_volume_size = x_sub_stride_ * y_sub_stride_ * z_stride_;*/
    auto end_itr = thrust::copy_if(
            thrust::device,
            thrust::make_counting_iterator<unsigned int>(0), // count indexes from 0
            thrust::make_counting_iterator<unsigned int>(padded_sub_volume_size), // ...to padded_sub_volume_size
            subdom_data->padded_map, //beginning of stencil sequence
            subdom_data->padded_map_idx, // beginning of sequence to copy into
            thrust::logical_not<int8_t>());//predicate test on every value

    subdom_data->padded_map_idx_size = end_itr - subdom_data->padded_map_idx;

    // set all padded map boundaries (still -1) to 0 for correctness to
    // distinguish boundaries
    thrust::replace(thrust::device, subdom_data->padded_map, subdom_data->padded_map + padded_sub_volume_size, -1, 0);

#ifdef DEBUG_OUTPUT
    cudaSafeCall(cudaStreamSynchronize(stream_data0->stream));
    logger_->info("calculate map idx {}", timer.get_laptime());

    logger_->info("padded_map_idx_size={}", subdom_data->padded_map_idx_size);

    timer.reset();
#endif


    // Each GPU each subdom_data
    // this set the dx and dy start idx for each stream
    unsigned int num_dx = get_num_blocks(x_sub_delta, dx_);
    unsigned int num_dy = get_num_blocks(y_sub_delta, dy_);
    unsigned int stream_id = 0;
    for (unsigned int dy_i = 0; dy_i < num_dy; dy_i++) {
        for (unsigned int dx_i = 0; dx_i < num_dx; dx_i++) {
            subdom_data->stream_data[stream_id]->dx_i_list.push_back(dx_i);
            subdom_data->stream_data[stream_id]->dy_i_list.push_back(dy_i);

            stream_id++;
            if (stream_id == num_streams_) {
                stream_id = 0;
            }
        }
    }
    cudaSafeCall(cudaStreamSynchronize(stream_data0->stream));

    cudaSafeCall(cudaFreeHost(padded_sub_map));
    cudaSafeCall(cudaFreeHost(padded_sub_image));
}

const cudautils::SiftParams Sift::get_sift_params() {
    return sift_params_;
}

void Sift::postrun() {
    // count keypoints
    int total_keypoints = 0;
    for (int gpu_id = 0; gpu_id < num_gpus_; gpu_id++) {
        std::shared_ptr<SubDomainDataOnGPU> subdom_data = subdom_data_[gpu_id];

        for (int stream_id = 0; stream_id < num_streams_; stream_id++) {
            std::shared_ptr<SubDomainDataOnStream> stream_data =
                subdom_data->stream_data[stream_id];

            total_keypoints += stream_data->keystore->len;
        }
    }

    // allocate for number of keypoints
    dom_data_->keystore->len = total_keypoints;
    cudaHostAlloc(&(dom_data_->keystore->buf), dom_data_->keystore->len *
            sizeof(cudautils::Keypoint), cudaHostAllocPortable);

    // copy keypoints to host
    int counter = 0;
    for (int gpu_id = 0; gpu_id < num_gpus_; gpu_id++) {
        std::shared_ptr<SubDomainDataOnGPU> subdom_data = subdom_data_[gpu_id];

        for (int stream_id = 0; stream_id < num_streams_; stream_id++) {
            std::shared_ptr<SubDomainDataOnStream> stream_data =
                subdom_data->stream_data[stream_id];

            for (int i = 0; i < stream_data->keystore->len; i++) {
                dom_data_->keystore->buf[counter] = stream_data->keystore->buf[i];
                counter++;
            }
        }
    }
    return;
}


void Sift::runOnStream(
        const int gpu_id,
        const int stream_id,
        const unsigned int gpu_task_id) {

    cudaSetDevice(gpu_id);

    std::shared_ptr<SubDomainDataOnGPU> subdom_data = subdom_data_[gpu_id];
    std::shared_ptr<SubDomainDataOnStream> stream_data = subdom_data->stream_data[stream_id];

    unsigned int x_sub_i = subdom_data->x_sub_i_list[gpu_task_id];
    unsigned int y_sub_i = subdom_data->y_sub_i_list[gpu_task_id];
    unsigned int x_sub_delta = get_delta(x_size_, x_sub_i, x_sub_size_);
    unsigned int y_sub_delta = get_delta(y_size_, y_sub_i, y_sub_size_);
    unsigned int x_sub_start = x_sub_i * x_sub_size_;
    unsigned int y_sub_start = y_sub_i * y_sub_size_;

#ifdef DEBUG_OUTPUT
    CudaTimer timer(stream_data->stream);
#endif

    // each stream has a individual subsections of data, that each kernel call will operate on
    // these subsections start/stop idx are determined by dx_i and dy_i lists
    for (auto dx_itr = stream_data->dx_i_list.begin(), dy_itr = stream_data->dy_i_list.begin();
            dx_itr != stream_data->dx_i_list.end() || dy_itr != stream_data->dy_i_list.end();
            dx_itr++, dy_itr++) {

        unsigned int dx_i = *dx_itr;
        unsigned int dy_i = *dy_itr;

        unsigned int dx_start = dx_i * dx_;
        unsigned int dx_delta = get_delta(x_sub_delta, dx_i, dx_);
        unsigned int dx_end   = dx_start + dx_delta;
        unsigned int dy_start = dy_i * dy_;
        unsigned int dy_delta = get_delta(y_sub_delta, dy_i, dy_);
        unsigned int dy_end   = dy_start + dy_delta;

#ifdef DEBUG_OUTPUT
        logger_->info("dx_i={}, dy_i={}", dx_i, dy_i);
        logger_->info("x=({},{},{}) y=({},{},{}), dw={}", dx_start, dx_delta, dx_end, dy_start, dy_delta, dy_end, dw_);
        logger_->info("subdom_data->padded_map_idx_size={}", subdom_data->padded_map_idx_size);
#endif

        // create each substream data on device
        unsigned int *substream_padded_map_idx;
        cudaSafeCall(cudaMalloc(&substream_padded_map_idx,
                    subdom_data->padded_map_idx_size * sizeof(unsigned int)));

        RangeCheck range_check { x_sub_stride_, y_sub_stride_,
            dx_start + dw_, dx_end + dw_, dy_start + dw_, dy_end + dw_, dw_, z_size_ + dw_ };

        // copy the relevant (in range) idx elements from the
        // global GPU padded_map_idx to the local substream_padded_map_idx 
        auto end_itr = thrust::copy_if(
                thrust::device,
                subdom_data->padded_map_idx,
                subdom_data->padded_map_idx + subdom_data->padded_map_idx_size,
                substream_padded_map_idx,
                range_check);

        unsigned int substream_padded_map_idx_size = end_itr - substream_padded_map_idx;

#ifdef DEBUG_OUTPUT
        logger_->info("substream_padded_map_idx_size={}", substream_padded_map_idx_size);
        logger_->info("transfer map idx {}", timer.get_laptime());

#ifdef DEBUG_OUTPUT_MATRIX
        cudaSafeCall(cudaStreamSynchronize(stream_data->stream));
        thrust::device_vector<unsigned int> dbg_d_padded_map_idx(substream_padded_map_idx,
                substream_padded_map_idx + substream_padded_map_idx_size);
        thrust::host_vector<unsigned int> dbg_h_padded_map_idx(dbg_d_padded_map_idx);
        for (unsigned int i = 0; i < substream_padded_map_idx_size; i++) {
            logger_->debug("substream_padded_map_idx={}", dbg_h_padded_map_idx[i]);
        }
#endif
        timer.reset();
#endif

        if (substream_padded_map_idx_size == 0) {
#ifdef DEBUG_OUTPUT
            logger_->debug("no map to be padded");
#endif
            continue;
        }

        /*
        Create an array to hold each descriptor ivec vector on VRAM 
        essentially a matrix of substream_padded_map_idx_size by descriptor length
        */
        uint8_t *descriptors;
        long desc_mem_size = sift_params_.descriptor_len * 
            substream_padded_map_idx_size * sizeof(uint8_t);
        cudaSafeCall(cudaMalloc(&descriptors, desc_mem_size));

        //FIXME num_threads should not be hardcoded
        // One keypoint per thread, one thread per block
        unsigned int num_threads = 1;
        // round up by number of threads per block, to calc num of blocks
        unsigned int num_blocks = get_num_blocks(substream_padded_map_idx_size, num_threads);

#ifdef DEBUG_OUTPUT
        /*cudaSafeCall(cudaStreamSynchronize(stream_data->stream));*/
        logger_->debug("num_blocks={}", num_blocks);
        logger_->debug("num_threads={}", num_threads);
#endif

        if (num_blocks * num_threads < substream_padded_map_idx_size) {
            logger_->info("Error occured in numblocks and num_threads estimation... returning from stream"); 
            return;
        }

#ifdef DEBUG_OUTPUT
        logger_->debug("create_descriptor");
#endif

        // sift_params.fv_centers must be placed on device since array passed to cuda kernel
        double* device_centers;
        cudaSafeCall(cudaMalloc((void **) &device_centers,
                    sizeof(double) * sift_params_.fv_centers_len));
        cudaSafeCall(cudaMemcpy((void *) device_centers, (const void *) fv_centers_,
                (size_t) sizeof(double) * sift_params_.fv_centers_len,
                cudaMemcpyHostToDevice));
        
#ifdef DEBUG_OUTPUT_MATRIX

        printf("Print image\n");
        cudaStreamSynchronize(stream_data->stream);
        int sub_volume_size = x_sub_stride_ * y_sub_stride_ * z_stride_;
        double* dbg_h_image = (double*) malloc(sizeof(double) * sub_volume_size);
        cudaSafeCall(cudaMemcpy((void **) dbg_h_image, subdom_data->padded_image,
                sizeof(double) * sub_volume_size,
                cudaMemcpyDeviceToHost));
        // print
        for (int i=0; i < sub_volume_size; i++) {
            if (dbg_h_image[i] != 0.0) {
                printf("host image[%d]: %f\n", i, dbg_h_image[i]);
            }
        }

#endif

        create_descriptor<<<num_blocks, num_threads, 0, stream_data->stream>>>(
                x_sub_stride_, y_sub_stride_, x_sub_start, y_sub_start, 
                dw_, // pad width
                substream_padded_map_idx_size, // total number of keypoints to process
                substream_padded_map_idx, //substream map, filtered linear idx into per GPU padded_map and padded_image
                subdom_data->padded_map,//global map split per GPU
                subdom_data->padded_image,//image split per GPU
                sift_params_, 
                device_centers,
                descriptors); 
        cudaCheckError();


#ifdef DEBUG_OUTPUT
        logger_->info("create descriptors elapsed: {}", timer.get_laptime());

        timer.reset();
#endif

        // transfer vector descriptors via host pinned memory for faster async cpy
        uint8_t *h_descriptors;
        cudaSafeCall(cudaHostAlloc((void **) &h_descriptors, desc_mem_size, cudaHostAllocPortable));
        
        cudaSafeCall(cudaMemcpyAsync(
                h_descriptors,
                descriptors,
                desc_mem_size,
                cudaMemcpyDeviceToHost, stream_data->stream));

        // transfer index map to host for referencing correct index
        unsigned int *h_padded_map_idx;
        cudaSafeCall(cudaHostAlloc((void **) &h_padded_map_idx, 
                    substream_padded_map_idx_size * sizeof(unsigned int),
                    cudaHostAllocPortable));

        cudaSafeCall(cudaMemcpyAsync(
                h_padded_map_idx,
                substream_padded_map_idx,
                substream_padded_map_idx_size * sizeof(unsigned int),
                cudaMemcpyDeviceToHost, stream_data->stream));

#ifdef DEBUG_OUTPUT_MATRIX
        /*for (int i=0; i < substream_padded_map_idx_size; i++) {*/
            /*printf("h_padded_map_idx:%u\n", h_padded_map_idx[i]);*/
            /*if (i % sift_params_.descriptor_len == 0) {*/
                /*printf("\n\nDescriptor:%d\n", (int) i / sift_params_.descriptor_len);*/
            /*}*/
            /*printf("%d: %d\n", i, h_descriptors[i]);*/
        /*}*/
#endif

        stream_data->keystore->len = substream_padded_map_idx_size ;
        cudaHostAlloc(&(stream_data->keystore->buf), stream_data->keystore->len *
                sizeof(cudautils::Keypoint), cudaHostAllocPortable);

        // make sure all streams are done
        cudaSafeCall(cudaStreamSynchronize(stream_data->stream));

        // save data for all streams to global Sift object store
        int skip_counter = 0;
        for (int i = 0; i < substream_padded_map_idx_size; i++) {
            if (std::isnan(h_padded_map_idx[i])) {
                skip_counter++;
                continue;
            } 

            Keypoint temp;
            temp.ivec = (uint8_t*) malloc(sift_params_.descriptor_len * sizeof(uint8_t));
            // FIXME is this faster than individual device to host transfers
            memcpy(temp.ivec, &(h_descriptors[i * sift_params_.descriptor_len]), 
                    sift_params_.descriptor_len * sizeof(uint8_t));
            temp.xyScale = sift_params_.xyScale;
            temp.tScale = sift_params_.tScale;

            unsigned int padding_x;
            unsigned int padding_y;
            unsigned int padding_z;
            ind2sub(x_sub_stride_, y_sub_stride_, h_padded_map_idx[i], padding_x, padding_y, padding_z);
            // correct for dw_ padding, matlab is 1-indexed
            temp.x = x_sub_start + padding_x - dw_ + 1;
            temp.y = y_sub_start + padding_y - dw_ + 1;
            temp.z = padding_z - dw_ + 1;

#ifdef DEBUG_OUTPUT_MATRIX
            /*logger_->info("XXX    desc_len={}, x_sub_start={}, y_sub_start={}, idx={}, temp.x={}, temp.y={}, temp.z={}",*/
                    /*sift_params_.descriptor_len, x_sub_start, y_sub_start, h_padded_map_idx[i], temp.x,*/
                    /*temp.y, temp.z);*/
            for (int desc_idx=0; desc_idx < sift_params_.descriptor_len; desc_idx++) {
                logger_->info("ivec[{}]={}", desc_idx, temp.ivec[desc_idx]);
            }
#endif
            // buffer the size of the whole image
            stream_data->keystore->buf[i - skip_counter] = temp;
        }
        // remove rejected keypoints
        auto new_end = thrust::remove_if(thrust::device,
                stream_data->keystore->buf, 
                stream_data->keystore->buf + stream_data->keystore->len,
                h_padded_map_idx, isnan_test());
        // update the len for transfer
        stream_data->keystore->len = substream_padded_map_idx_size -
            skip_counter;

#ifdef DEBUG_OUTPUT
        cudaSafeCall(cudaStreamSynchronize(stream_data->stream));
        logger_->info("stream_data->keystore->len={}, new_end - stream_data->keystore->buf={}",
                stream_data->keystore->len, new_end - stream_data->keystore->buf);
#endif
        assert(stream_data->keystore->len == (new_end - stream_data->keystore->buf));

        /*cudaSafeCall(cudaFree(d_sift_params));*/
        cudaSafeCall(cudaFree(substream_padded_map_idx));
        cudaSafeCall(cudaFree(descriptors));
        cudaSafeCall(cudaFree(device_centers));

        cudaSafeCall(cudaFreeHost(h_descriptors));
        cudaSafeCall(cudaFreeHost(h_padded_map_idx));

#ifdef DEBUG_OUTPUT
        logger_->info("transfer d2h and copy descriptor ivec values {}", timer.get_laptime());

#endif
    }
}


} // namespace cudautils

