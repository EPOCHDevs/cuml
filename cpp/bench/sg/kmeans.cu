/*
 * Copyright (c) 2019, NVIDIA CORPORATION.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <cuML.hpp>
#include <kmeans/kmeans.hpp>
#include "dataset.h"
#include "harness.h"

namespace ML {
namespace Bench {
namespace kmeans {

template <typename D>
struct Params : public BlobsParams<D> {
  // algo related
  ML::kmeans::KMeansParams p;

  std::string str() const {
    std::ostringstream oss;
    oss << PARAM(p.init) << PARAM(p.max_iter) << PARAM(p.tol) << PARAM(p.metric)
        << PARAM(p.oversampling_factor) << PARAM(p.batch_size)
        << PARAM(p.inertia_check);
    return BlobsParams<D>::str() + oss.str();
  }
};

template <typename D>
struct Run : public Benchmark<Params<D>> {
  void setup() {
    const auto& p = this->getParams();
    CUDA_CHECK(cudaStreamCreate(&stream));
    handle.reset(new cumlHandle);
    handle->setStream(stream);
    auto allocator = handle->getDeviceAllocator();
    labels = (int*)allocator->allocate(p.nrows * sizeof(int), stream);
    centroids =
      (D*)allocator->allocate(p.nclasses * p.ncols * sizeof(D), stream);
    dataset.blobs(*handle, p.nrows, p.ncols, p.rowMajor, p.nclasses,
                  p.cluster_std, p.shuffle, p.center_box_min, p.center_box_max,
                  p.seed);
    CUDA_CHECK(cudaStreamSynchronize(stream));
  }

  void teardown() {
    const auto& p = this->getParams();
    CUDA_CHECK(cudaStreamSynchronize(stream));
    auto allocator = handle->getDeviceAllocator();
    allocator->deallocate(labels, p.nrows * sizeof(int), stream);
    allocator->deallocate(centroids, p.nclasses * p.ncols * sizeof(D), stream);
    dataset.deallocate(*handle);
    CUDA_CHECK(cudaStreamSynchronize(stream));
    CUDA_CHECK(cudaStreamDestroy(stream));
  }

  ///@todo: implement
  void metrics(RunInfo& ri) {}

  void run() {
    const auto& p = this->getParams();
    ASSERT(p.rowMajor, "Kmeans only supports row-major inputs");
    ML::kmeans::fit_predict(*handle, p.p, dataset.X, p.nrows, p.ncols,
                            centroids, labels, inertia, nIter);
    CUDA_CHECK(cudaStreamSynchronize(handle->getStream()));
  }

 private:
  std::shared_ptr<cumlHandle> handle;
  cudaStream_t stream;
  int* labels;
  D* centroids;
  Dataset<D, int> dataset;
  int nIter;
  D inertia;
};

template <typename D>
std::vector<Params<D>> getInputs() {
  std::vector<Params<D>> out;
  Params<D> p;
  p.rowMajor = true;
  p.cluster_std = (D)1.0;
  p.shuffle = false;
  p.center_box_min = (D)-10.0;
  p.center_box_max = (D)10.0;
  p.seed = 12345ULL;
  p.p.init = (ML::kmeans::KMeansParams::InitMethod)0;
  p.p.max_iter = 300;
  p.p.tol = (D)1e-4;
  p.p.verbose = false;
  p.p.seed = p.seed;
  p.p.metric = 0;  // L2
  p.p.inertia_check = true;
  std::vector<std::pair<int, int>> rowcols = {
    {160000, 64},
    {320000, 64},
    {640000, 64},
  };
  for (auto& rc : rowcols) {
    p.nrows = rc.first;
    p.ncols = rc.second;
    for (auto nclass : std::vector<int>({8, 16, 32})) {
      p.nclasses = nclass;
      p.p.n_clusters = p.nclasses;
      for (auto bs_shift : std::vector<int>({16, 18})) {
        p.p.batch_size = 1 << bs_shift;
        out.push_back(p);
      }
    }
  }
  return out;
}

REGISTER_BENCH(Run<float>, Params<float>, kmeansF, getInputs<float>());
REGISTER_BENCH(Run<double>, Params<double>, kmeansD, getInputs<double>());

}  // end namespace kmeans
}  // end namespace Bench
}  // end namespace ML
