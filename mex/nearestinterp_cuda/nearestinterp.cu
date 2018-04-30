#include <iostream>
#include <future>

#include <thrust/copy.h>
#include <thrust/replace.h>
#include <thrust/functional.h>
#include <thrust/iterator/counting_iterator.h>

#include <cuda_runtime.h>

#include "nearestinterp.h"
#include "matrix_helper.h"
#include "cuda_timer.h"

#include "spdlog/spdlog.h"


namespace cudautils {

// interpolate image data
//
__global__
void interpolate_volumes(
        unsigned int x_stride,
        unsigned int y_stride,
        unsigned int map_idx_size,
        unsigned int *map_idx,
        int8_t *map,
        double *image,
        double *interpolated_values) {

    unsigned int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= map_idx_size) return;

    unsigned int idx_zplane = map_idx[i] - 1 - x_stride - (x_stride * y_stride); // move current pos idx by (-1, -1, -1)
    unsigned int idx = idx_zplane;

    int sum_idx = 0;
    double sum = 0.0;

    // (-1, -1, -1)  ->  (1, -1, -1)
    sum += image[idx + 0] * double(map[idx + 0]);   sum_idx += (map[idx + 0] > 0);
    sum += image[idx + 1] * double(map[idx + 1]);   sum_idx += (map[idx + 1] > 0);
    sum += image[idx + 2] * double(map[idx + 2]);   sum_idx += (map[idx + 2] > 0);

    // (-1, 0, -1)  ->  (1, 0, -1)
    idx += x_stride;
    sum += image[idx + 0] * double(map[idx + 0]);   sum_idx += (map[idx + 0] > 0);
    sum += image[idx + 1] * double(map[idx + 1]);   sum_idx += (map[idx + 1] > 0);
    sum += image[idx + 2] * double(map[idx + 2]);   sum_idx += (map[idx + 2] > 0);

    // (-1, 1, -1)  ->  (1, 1, -1)
    idx += x_stride;
    sum += image[idx + 0] * double(map[idx + 0]);   sum_idx += (map[idx + 0] > 0);
    sum += image[idx + 1] * double(map[idx + 1]);   sum_idx += (map[idx + 1] > 0);
    sum += image[idx + 2] * double(map[idx + 2]);   sum_idx += (map[idx + 2] > 0);

    idx_zplane += x_stride * y_stride;
    idx = idx_zplane;

    // (-1, -1, 0)  ->  (1, -1, 0)
    sum += image[idx + 0] * double(map[idx + 0]);   sum_idx += (map[idx + 0] > 0);
    sum += image[idx + 1] * double(map[idx + 1]);   sum_idx += (map[idx + 1] > 0);
    sum += image[idx + 2] * double(map[idx + 2]);   sum_idx += (map[idx + 2] > 0);

    // (-1, 0, 0)  ->  (1, 0, 0)
    idx += x_stride;
    sum += image[idx + 0] * double(map[idx + 0]);   sum_idx += (map[idx + 0] > 0);
    sum += image[idx + 1] * double(map[idx + 1]);   sum_idx += (map[idx + 1] > 0);
    sum += image[idx + 2] * double(map[idx + 2]);   sum_idx += (map[idx + 2] > 0);

    // (-1, 1, 0)  ->  (1, 1, 0)
    idx += x_stride;
    sum += image[idx + 0] * double(map[idx + 0]);   sum_idx += (map[idx + 0] > 0);
    sum += image[idx + 1] * double(map[idx + 1]);   sum_idx += (map[idx + 1] > 0);
    sum += image[idx + 2] * double(map[idx + 2]);   sum_idx += (map[idx + 2] > 0);

    idx_zplane += x_stride * y_stride;
    idx = idx_zplane;

    // (-1, -1, 1)  ->  (1, -1, 1)
    sum += image[idx + 0] * double(map[idx + 0]);   sum_idx += (map[idx + 0] > 0);
    sum += image[idx + 1] * double(map[idx + 1]);   sum_idx += (map[idx + 1] > 0);
    sum += image[idx + 2] * double(map[idx + 2]);   sum_idx += (map[idx + 2] > 0);

    // (-1, 0, 1)  ->  (1, 0, 1)
    idx += x_stride;
    sum += image[idx + 0] * double(map[idx + 0]);   sum_idx += (map[idx + 0] > 0);
    sum += image[idx + 1] * double(map[idx + 1]);   sum_idx += (map[idx + 1] > 0);
    sum += image[idx + 2] * double(map[idx + 2]);   sum_idx += (map[idx + 2] > 0);

    // (-1, 1, 1)  ->  (1, 1, 1)
    idx += x_stride;
    sum += image[idx + 0] * double(map[idx + 0]);   sum_idx += (map[idx + 0] > 0);
    sum += image[idx + 1] * double(map[idx + 1]);   sum_idx += (map[idx + 1] > 0);
    sum += image[idx + 2] * double(map[idx + 2]);   sum_idx += (map[idx + 2] > 0);

    if (sum_idx > 0) {
        interpolated_values[i] = sum / double(sum_idx);
    } else {
        idx_zplane = map_idx[i] - 2 * (1 + x_stride + (x_stride * y_stride)); // move current pos idx by (-2, -2, -2)

        // (u, v, w) <- (x, y, z)
        // u=0-4 v=0-4 w=0,4
        idx = idx_zplane;
        for (unsigned int v = 0; v < 5; v++) {
            sum += image[idx + 0] * double(map[idx + 0]);   sum_idx += (map[idx + 0] > 0);
            sum += image[idx + 1] * double(map[idx + 1]);   sum_idx += (map[idx + 1] > 0);
            sum += image[idx + 2] * double(map[idx + 2]);   sum_idx += (map[idx + 2] > 0);
            sum += image[idx + 3] * double(map[idx + 3]);   sum_idx += (map[idx + 3] > 0);
            sum += image[idx + 4] * double(map[idx + 4]);   sum_idx += (map[idx + 4] > 0);
            idx += x_stride;
        }
        idx = idx_zplane + 4 * x_stride * y_stride;
        for (unsigned int v = 0; v < 5; v++) {
            sum += image[idx + 0] * double(map[idx + 0]);   sum_idx += (map[idx + 0] > 0);
            sum += image[idx + 1] * double(map[idx + 1]);   sum_idx += (map[idx + 1] > 0);
            sum += image[idx + 2] * double(map[idx + 2]);   sum_idx += (map[idx + 2] > 0);
            sum += image[idx + 3] * double(map[idx + 3]);   sum_idx += (map[idx + 3] > 0);
            sum += image[idx + 4] * double(map[idx + 4]);   sum_idx += (map[idx + 4] > 0);
            idx += x_stride;
        }


        // u=0-4 v=0,4 w=1-3
        for (unsigned int w = 1; w < 4; w++) {
            idx = idx_zplane + w * x_stride * y_stride;
            sum += image[idx + 0] * double(map[idx + 0]);   sum_idx += (map[idx + 0] > 0);
            sum += image[idx + 1] * double(map[idx + 1]);   sum_idx += (map[idx + 1] > 0);
            sum += image[idx + 2] * double(map[idx + 2]);   sum_idx += (map[idx + 2] > 0);
            sum += image[idx + 3] * double(map[idx + 3]);   sum_idx += (map[idx + 3] > 0);
            sum += image[idx + 4] * double(map[idx + 4]);   sum_idx += (map[idx + 4] > 0);
            idx += 4 * x_stride;
            sum += image[idx + 0] * double(map[idx + 0]);   sum_idx += (map[idx + 0] > 0);
            sum += image[idx + 1] * double(map[idx + 1]);   sum_idx += (map[idx + 1] > 0);
            sum += image[idx + 2] * double(map[idx + 2]);   sum_idx += (map[idx + 2] > 0);
            sum += image[idx + 3] * double(map[idx + 3]);   sum_idx += (map[idx + 3] > 0);
            sum += image[idx + 4] * double(map[idx + 4]);   sum_idx += (map[idx + 4] > 0);
        }

        // u=0,4 v=1-3 w=1-3
        for (unsigned int w = 1; w < 4; w++) {
            idx = idx_zplane + w * x_stride * y_stride;
            idx += x_stride;
            sum += image[idx + 0] * double(map[idx + 0]);   sum_idx += (map[idx + 0] > 0);
            sum += image[idx + 4] * double(map[idx + 4]);   sum_idx += (map[idx + 4] > 0);
            idx += x_stride;
            sum += image[idx + 0] * double(map[idx + 0]);   sum_idx += (map[idx + 0] > 0);
            sum += image[idx + 4] * double(map[idx + 4]);   sum_idx += (map[idx + 4] > 0);
            idx += x_stride;
            sum += image[idx + 0] * double(map[idx + 0]);   sum_idx += (map[idx + 0] > 0);
            sum += image[idx + 4] * double(map[idx + 4]);   sum_idx += (map[idx + 4] > 0);
        }

        if (sum_idx > 0) {
            interpolated_values[i] = sum / double(sum_idx);
        } else {
            interpolated_values[i] = 0.0;
        }
    }
    return;
}


NearestInterp::NearestInterp(
        const unsigned int x_size,
        const unsigned int y_size,
        const unsigned int z_size,
        const unsigned int x_sub_size,
        const unsigned int y_sub_size,
        const unsigned int dx,
        const unsigned int dy,
        const unsigned int dw,
        const unsigned int num_gpus,
        const unsigned int num_streams)
    : x_size_(x_size), y_size_(y_size), z_size_(z_size),
        x_sub_size_(x_sub_size), y_sub_size_(y_sub_size),
        dx_(dx), dy_(dy), dw_(dw),
        num_gpus_(num_gpus), num_streams_(num_streams),
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

NearestInterp::~NearestInterp() {
    for (unsigned int i = 0; i < num_gpus_; i++) {
        for (unsigned int j = 0; j < num_streams_; j++) {
            cudaStreamDestroy(subdom_data_[i]->stream_data[j]->stream);
        }
    }

    //logger_->flush();
}

void NearestInterp::setImage(const double *img)
{
    assert((x_size_ * y_size_ * z_size_) == dom_data_->h_image.size());

    thrust::copy(img, img + (x_size_ * y_size_ * z_size_), dom_data_->h_image.begin());
}

void NearestInterp::setImage(const std::vector<double>& img)
{
    assert((x_size_ * y_size_ * z_size_) == dom_data_->h_image.size());
    assert(img.size() == dom_data_->h_image.size());

    thrust::copy(img.begin(), img.end(), dom_data_->h_image.begin());
}

void NearestInterp::setMapToBeInterpolated(const int8_t *map)
{
    assert((x_size_ * y_size_ * z_size_) == dom_data_->h_map.size());

    thrust::copy(map, map + (x_size_ * y_size_ * z_size_), dom_data_->h_map.begin());
}

void NearestInterp::setMapToBeInterpolated(const std::vector<int8_t>& map)
{
    assert((x_size_ * y_size_ * z_size_) == dom_data_->h_map.size());
    assert(map.size() == dom_data_->h_map.size());

    thrust::copy(map.begin(), map.end(), dom_data_->h_map.begin());
}

void NearestInterp::getImage(double *img)
{
    thrust::copy(dom_data_->h_image.begin(), dom_data_->h_image.end(), img);
}

void NearestInterp::getImage(std::vector<double>& img)
{
    thrust::copy(dom_data_->h_image.begin(), dom_data_->h_image.end(), img.begin());
}


int NearestInterp::getNumOfGPUTasks(const int gpu_id) {
    return subdom_data_[gpu_id]->x_sub_i_list.size();
}

int NearestInterp::getNumOfStreamTasks(
        const int gpu_id,
        const int stream_id) {
    return 1;
}

void NearestInterp::runOnGPU(
        const int gpu_id,
        const unsigned int gpu_task_id) {

    cudaSetDevice(gpu_id);

    std::shared_ptr<SubDomainDataOnGPU> subdom_data = subdom_data_[gpu_id];
    std::shared_ptr<SubDomainDataOnStream> stream_data0 = subdom_data->stream_data[0];

    unsigned int x_sub_i = subdom_data->x_sub_i_list[gpu_task_id];
    unsigned int y_sub_i = subdom_data->y_sub_i_list[gpu_task_id];
#ifdef DEBUG_OUTPUT
    CudaTimer timer;
    logger_->info("===== gpu_id={} x_sub_i={} y_sub_i={}", gpu_id, x_sub_i, y_sub_i);
#endif

    unsigned int x_sub_start = x_sub_i * x_sub_size_;
    unsigned int x_sub_delta = get_delta(x_size_, x_sub_i, x_sub_size_);
    unsigned int y_sub_start = y_sub_i * y_sub_size_;
    unsigned int y_sub_delta = get_delta(y_size_, y_sub_i, y_sub_size_);
    unsigned int base_x_sub  = (x_sub_i > 0 ? 0 : dw_);
    unsigned int base_y_sub  = (y_sub_i > 0 ? 0 : dw_);

    unsigned int padding_x_sub_start = x_sub_start - (x_sub_i > 0 ? dw_ : 0);
    unsigned int padding_x_sub_delta = x_sub_delta + (x_sub_i > 0 ? dw_ : 0) + (x_sub_i < num_x_sub_ - 1 ? dw_ : 0);
    unsigned int padding_y_sub_start = y_sub_start - (y_sub_i > 0 ? dw_ : 0);
    unsigned int padding_y_sub_delta = y_sub_delta + (y_sub_i > 0 ? dw_ : 0) + (y_sub_i < num_y_sub_ - 1 ? dw_ : 0);
#ifdef DEBUG_OUTPUT
    unsigned int x_sub_end = x_sub_start + x_sub_delta;
    unsigned int y_sub_end = y_sub_start + y_sub_delta;
    logger_->debug("x_sub=({},{},{}) y_sub=({},{},{})", x_sub_start, x_sub_delta, x_sub_end, y_sub_start, y_sub_delta, y_sub_end);
    logger_->debug("base_x_sub={},base_y_sub={}", base_x_sub, base_y_sub);
#endif

    thrust::host_vector<int8_t> padded_sub_map  (x_sub_stride_ * y_sub_stride_ * z_stride_, -1);
    thrust::host_vector<double> padded_sub_image(x_sub_stride_ * y_sub_stride_ * z_stride_);

    for (unsigned int k = 0; k < z_size_; k++) {
        for (unsigned int j = 0; j < padding_y_sub_delta; j++) {
            size_t src_idx = dom_data_->sub2ind(padding_x_sub_start, padding_y_sub_start + j, k);
            size_t dst_idx = subdom_data->pad_sub2ind(base_x_sub, base_y_sub + j, dw_ + k);

            int8_t* src_map_begin = &(dom_data_->h_map[src_idx]);
            int8_t* dst_map_begin = &(padded_sub_map[dst_idx]);
            thrust::copy(src_map_begin, src_map_begin + padding_x_sub_delta, dst_map_begin);

            double* src_image_begin = &(dom_data_->h_image[src_idx]);
            double* dst_image_begin = &(padded_sub_image[dst_idx]);
            thrust::copy(src_image_begin, src_image_begin + padding_x_sub_delta, dst_image_begin);
        }
    }

    thrust::fill(subdom_data->padded_image.begin(), subdom_data->padded_image.end(), 0.0);

    cudaMemcpyAsync(
            thrust::raw_pointer_cast(subdom_data->padded_image.data()),
            thrust::raw_pointer_cast(padded_sub_image.data()),
            x_sub_stride_ * y_sub_stride_ * z_stride_ * sizeof(double),
            cudaMemcpyHostToDevice, stream_data0->stream);

#ifdef DEBUG_OUTPUT
    cudaStreamSynchronize(stream_data0->stream);
    logger_->info("transfer image data {}", timer.get_laptime());

#ifdef DEBUG_OUTPUT_MATRIX
    logger_->info("===== dev image");
    print_matrix3d(logger_, x_size_, y_size_, 0, 0, 0, x_size_, y_size_, z_size_, dom_data_->h_image);
    print_matrix3d(logger_, x_sub_stride_, y_sub_stride_, 0, 0, 0, x_sub_stride_, y_sub_stride_, z_stride_, subdom_data->padded_image);
#endif

    timer.reset();
#endif

    cudaMemcpyAsync(
            thrust::raw_pointer_cast(subdom_data->padded_map.data()),
            thrust::raw_pointer_cast(padded_sub_map.data()),
            x_sub_stride_ * y_sub_stride_ * z_stride_ * sizeof(int8_t),
            cudaMemcpyHostToDevice, stream_data0->stream);

#ifdef DEBUG_OUTPUT
    cudaStreamSynchronize(stream_data0->stream);
    logger_->info("transfer map data {}", timer.get_laptime());

#ifdef DEBUG_OUTPUT_MATRIX
    logger_->debug("===== dev map");
    print_matrix3d(logger_, x_size_, y_size_, 0, 0, 0, x_size_, y_size_, z_size_, dom_data_->h_map);
    print_matrix3d(logger_, x_sub_stride_, y_sub_stride_, 0, 0, 0, x_sub_stride_, y_sub_stride_, z_stride_, subdom_data->padded_map);
#endif

    timer.reset();
#endif

    thrust::fill(subdom_data->padded_map_idx.begin(), subdom_data->padded_map_idx.end(), 0.0);

    auto end_itr = thrust::copy_if(
            thrust::make_counting_iterator<unsigned int>(0),
            thrust::make_counting_iterator<unsigned int>(x_sub_stride_ * y_sub_stride_ * z_stride_),
            subdom_data->padded_map.begin(),
            subdom_data->padded_map_idx.begin(),
            thrust::logical_not<int8_t>());

    subdom_data->padded_map_idx_size = end_itr - subdom_data->padded_map_idx.begin();

    thrust::replace(subdom_data->padded_map.begin(), subdom_data->padded_map.end(), -1, 0);

#ifdef DEBUG_OUTPUT
    cudaStreamSynchronize(stream_data0->stream);
    logger_->info("calculate map idx {}", timer.get_laptime());

    logger_->info("padded_map_idx_size={}", subdom_data->padded_map_idx_size);
//    logger_->debug("===== padded_map idx");
//    std::copy(subdom_data->padded_map_idx.begin(), end_itr, std::ostream_iterator<unsigned int>(std::cout, ","));
//    std::cout << std::endl;

    timer.reset();
#endif


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
    cudaStreamSynchronize(stream_data0->stream);
}

void NearestInterp::runOnStream(
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

#ifdef DEBUG_OUTPUT
    CudaTimer timer(stream_data->stream);
#endif

    for (auto dx_itr = stream_data->dx_i_list.begin(), dy_itr = stream_data->dy_i_list.begin();
            dx_itr != stream_data->dx_i_list.end() || dy_itr != stream_data->dy_i_list.end(); dx_itr++, dy_itr++) {

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
#endif


        thrust::device_vector<unsigned int> padded_map_idx(dx_delta * dy_delta * z_size_);

        RangeCheck range_check { x_sub_stride_, y_sub_stride_,
            dx_start + dw_, dx_end + dw_, dy_start + dw_, dy_end + dw_, dw_, z_size_ + dw_ };

        auto end_itr = thrust::copy_if(
                subdom_data->padded_map_idx.begin(),
                subdom_data->padded_map_idx.begin() + subdom_data->padded_map_idx_size,
                padded_map_idx.begin(),
                range_check);

        unsigned int padded_map_idx_size = end_itr - padded_map_idx.begin();

#ifdef DEBUG_OUTPUT
        logger_->info("padded_map_idx_size={}", padded_map_idx_size);
        logger_->info("transfer map idx {}", timer.get_laptime());

        cudaStreamSynchronize(stream_data->stream);

        for (auto map_idx_itr = padded_map_idx.begin(); map_idx_itr != end_itr; map_idx_itr++) {
            logger_->debug("h_padded_map_idx={}", *map_idx_itr);
        }
        timer.reset();
#endif
        if (padded_map_idx_size == 0) {
#ifdef DEBUG_OUTPUT
            logger_->debug("no map to be padded");
#endif
            continue;
        }

        thrust::device_vector<double> interpolated_values(padded_map_idx_size);


        unsigned int num_blocks = get_num_blocks(padded_map_idx_size, 1024);
#ifdef DEBUG_OUTPUT
        logger_->info("num_blocks={}", num_blocks);
#endif

        interpolate_volumes<<<num_blocks, 1024, 0, stream_data->stream>>>(
                x_sub_stride_, y_sub_stride_, padded_map_idx_size,
                thrust::raw_pointer_cast(padded_map_idx.data()),
                thrust::raw_pointer_cast(subdom_data->padded_map.data()),
                thrust::raw_pointer_cast(subdom_data->padded_image.data()),
                thrust::raw_pointer_cast(interpolated_values.data()));

#ifdef DEBUG_OUTPUT
        logger_->info("interpolate volumes {}", timer.get_laptime());

        //debug
//        cudaStreamSynchronize(stream_data->stream);
//        std::copy(interpolated_values.begin(),
//                  interpolated_values.begin() + padded_map_idx_size,
//                  std::ostream_iterator<double>(std::cout, ","));
//        std::cout << std::endl;

        timer.reset();
#endif

        pinnedDblHostVector h_interpolated_values(padded_map_idx_size);

        cudaMemcpyAsync(
                thrust::raw_pointer_cast(h_interpolated_values.data()),
                thrust::raw_pointer_cast(interpolated_values.data()),
                padded_map_idx_size * sizeof(double),
                cudaMemcpyDeviceToHost, stream_data->stream);

        pinnedUIntHostVector h_padded_map_idx(padded_map_idx_size);

        cudaMemcpyAsync(
                thrust::raw_pointer_cast(h_padded_map_idx.data()),
                thrust::raw_pointer_cast(padded_map_idx.data()),
                padded_map_idx_size * sizeof(unsigned int),
                cudaMemcpyDeviceToHost, stream_data->stream);

        cudaStreamSynchronize(stream_data->stream);
        for (unsigned int i = 0; i < padded_map_idx_size; i++) {
            unsigned int padding_x;
            unsigned int padding_y;
            unsigned int padding_z;
            ind2sub(x_sub_stride_, y_sub_stride_, h_padded_map_idx[i], padding_x, padding_y, padding_z);
            size_t idx = dom_data_->sub2ind(padding_x - dw_, padding_y - dw_, padding_z - dw_);

            dom_data_->h_image[idx] = h_interpolated_values[i];
        }

#ifdef DEBUG_OUTPUT
        logger_->info("transfer d2h and copy interpolated values {}", timer.get_laptime());

#ifdef DEBUG_OUTPUT_MATRIX
        logger_->debug("===== host interp image");
        print_matrix3d(logger_, x_size_, y_size_, 0, 0, 0, x_size_, y_size_, z_size_, dom_data_->h_image);
#endif
#endif
    }
}


} // namespace cudautils

