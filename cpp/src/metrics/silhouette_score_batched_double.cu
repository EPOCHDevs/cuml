
/*
 * Copyright (c) 2021-2024, NVIDIA CORPORATION.
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

#include <cuml/metrics/metrics.hpp>

#include <raft/core/handle.hpp>
#include <raft/stats/silhouette_score.cuh>

#include <cuvs/distance/distance.hpp>

namespace ML {

namespace Metrics {
namespace Batched {

double silhouette_score(const raft::handle_t& handle,
                        double* X,
                        int n_rows,
                        int n_cols,
                        int* y,
                        int n_labels,
                        double* scores,
                        int chunk,
                        cuvs::distance::DistanceType metric)
{
  return raft::stats::silhouette_score_batched<double, int, int>(
    handle,
    X,
    n_rows,
    n_cols,
    y,
    n_labels,
    scores,
    chunk,
    static_cast<raft::distance::DistanceType>(metric));
}

}  // namespace Batched

}  // namespace Metrics
}  // namespace ML
