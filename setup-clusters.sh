#!/usr/bin/env bash

# Sets up a multi-cluster Istio lab with one primary and two remotes.
#
# Loosely adapted from:
#   https://istio.io/v1.15/docs/setup/install/multicluster/primary-remote/
#   https://github.com/istio/common-files/blob/release-1.15/files/common/scripts/kind_provisioner.sh

set -eu
set -o pipefail

source "${BASH_SOURCE[0]%/*}"/lib/logging.sh
source "${BASH_SOURCE[0]%/*}"/lib/kind.sh
source "${BASH_SOURCE[0]%/*}"/lib/metallb.sh


# ---- Definitions: clusters ----

declare -A cluster_thanos=(
  [name]=thanos
  [pod_subnet]=10.10.0.0/16
  [svc_subnet]=10.255.10.0/24
  [metallb_l2pool_start]=10
)

declare -A cluster_remote1=(
  [name]=remote1
  [pod_subnet]=10.20.0.0/16
  [svc_subnet]=10.255.20.0/24
)

declare -A cluster_remote2=(
  [name]=remote2
  [pod_subnet]=10.30.0.0/16
  [svc_subnet]=10.255.30.0/24
)

#--------------------------------------

# Create clusters

log::msg "Creating KinD clusters"

kind::cluster::create ${cluster_thanos[name]} ${cluster_thanos[pod_subnet]} ${cluster_thanos[svc_subnet]} &
kind::cluster::create ${cluster_remote1[name]}  ${cluster_remote1[pod_subnet]}  ${cluster_remote1[svc_subnet]} &
kind::cluster::create ${cluster_remote2[name]}  ${cluster_remote2[pod_subnet]}  ${cluster_remote2[svc_subnet]} &
wait

kind::cluster::wait_ready ${cluster_thanos[name]}
kind::cluster::wait_ready ${cluster_remote1[name]}
kind::cluster::wait_ready ${cluster_remote2[name]}

# Add cross-cluster routes

declare thanos_cidr
declare remote1_cidr
declare remote2_cidr
thanos_cidr=$(kind::cluster::pod_cidr ${cluster_thanos[name]})
remote1_cidr=$(kind::cluster::pod_cidr  ${cluster_remote1[name]})
remote2_cidr=$(kind::cluster::pod_cidr  ${cluster_remote2[name]})

declare thanos_ip
declare remote1_ip
declare remote2_ip
thanos_ip=$(kind::cluster::node_ip ${cluster_thanos[name]})
remote1_ip=$(kind::cluster::node_ip  ${cluster_remote1[name]})
remote2_ip=$(kind::cluster::node_ip  ${cluster_remote2[name]})

log::msg "Adding routes to other clusters"

kind::cluster::add_route ${cluster_thanos[name]} ${remote1_cidr}  ${remote1_ip}
kind::cluster::add_route ${cluster_thanos[name]} ${remote2_cidr}  ${remote2_ip}

kind::cluster::add_route ${cluster_remote1[name]}  ${thanos_cidr} ${thanos_ip}
kind::cluster::add_route ${cluster_remote1[name]}  ${remote2_cidr}  ${remote2_ip}

kind::cluster::add_route ${cluster_remote2[name]}  ${thanos_cidr} ${thanos_ip}
kind::cluster::add_route ${cluster_remote2[name]}  ${remote1_cidr}  ${remote1_ip}

# Deploy MetalLB

log::msg "Deploying MetalLB inside clusters"

metallb::deploy ${cluster_thanos[name]} ${cluster_thanos[metallb_l2pool_start]}
metallb::deploy ${cluster_remote1[name]} ${cluster_thanos[metallb_l2pool_start]}
metallb::deploy ${cluster_remote2[name]} ${cluster_thanos[metallb_l2pool_start]}

