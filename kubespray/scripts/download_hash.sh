#!/usr/bin/env bash

set -o errexit
set -o pipefail
if [[ ${DEBUG:-false} == "true" ]]; then
    set -o xtrace
fi

checksums_file="$(git rev-parse --show-toplevel)/roles/kubespray-defaults/defaults/main/checksums.yml"
downloads_folder=/tmp/kubespray_binaries
default_file="$(git rev-parse --show-toplevel)/roles/kubespray-defaults/defaults/main/main.yml"
kube_min_version="$(grep kube_version_min_required ${default_file} | sed -E 's|kube_version_min_required: v(.*)|\1|g')"

function filter_version() {
    while read version; do
        if [[ "${version}" =~ ^v?[0-9]*\.[0-9]*\.[0-9]*$ ]]; then
            echo "${version}"
        fi
    done < /dev/stdin
}

function min_version() {
    local min_version="$1"
    local func_filter="${2:-filter_version}"
    while read version; do
        if _vercmp "${version#v}" '>=' "${min_version}"; then
            echo "${version}"
        fi
    done | "${func_filter}"
}

function limit_version() {
    local number_versions="${1:-7}"
    local func_filter="${2:-filter_version}"

    "${func_filter}" | head -n "${number_versions}"
}

function gvisor_version_filter() {
    while read version; do
        echo "${version}" | sed -E 's|^release-(.*)\..*$|\1|'
    done | head -n 8
}

function get_versions() {
    local type="$1"
    local name="$2"
    local version_func="${3:-limit_version}"
    if [ "$#" -ge 3 ]; then
        shift 3
    else
        shift 2
    fi

    local version=""
    local attempt_counter=0
    readonly max_attempts=5

    until [ "$version" ]; do
        version=$("_get_$type" "$name" "${version_func}" "$@")
        if _vercmp "${version#v}" '<' "${min_version}"; then
            continue
        elif [ "$version" ] ; then
            break
        elif [ ${attempt_counter} -eq ${max_attempts} ]; then
            echo "Max attempts reached" >&2
            exit 1
        fi
        attempt_counter=$((attempt_counter + 1))
        sleep $((attempt_counter * 2))
    done

    echo "${version}"
}

function _get_github_tags() {
    local repo="$1"
    local version_func="$2"
    shift 2

    # The number of results per page (max 50).
    tags="$(curl -s "https://api.github.com/repos/$repo/tags?per_page=50")"
    if [ "$tags" ]; then
        echo "$tags" | grep -Po '"name":.*?[^\\]",' | awk -F '"' '{print $4}' | "$version_func" "$@"
    fi
}

function _vercmp() {
    local v1=$1
    local op=$2
    local v2=$3
    local result

    # sort the two numbers with sort's "-V" argument.  Based on if v2
    # swapped places with v1, we can determine ordering.
    result=$(echo -e "$v1\n$v2" | sort -V | head -1)

    case $op in
    "==")
        [ "$v1" = "$v2" ]
        return
        ;;
    ">")
        [ "$v1" != "$v2" ] && [ "$result" = "$v2" ]
        return
        ;;
    "<")
        [ "$v1" != "$v2" ] && [ "$result" = "$v1" ]
        return
        ;;
    ">=")
        [ "$result" = "$v2" ]
        return
        ;;
    "<=")
        [ "$result" = "$v1" ]
        return
        ;;
    *)
        echo "unrecognised op: $op"
        exit 1
        ;;
    esac
}

function get_checksums() {
    local binary="$1"
    local version_exceptions="cri_dockerd_archive nerdctl_archive containerd_archive youki"
    declare -A skip_archs=(
["crio_archive"]="arm"
["calicoctl_binary"]="arm"
["ciliumcli_binary"]="arm ppc64le"
["etcd_binary"]="arm"
["cri_dockerd_archive"]="arm ppc64le"
["runc"]="arm"
["crun"]="arm ppc64le"
["youki"]="arm arm64 ppc64le"
["kata_containers_binary"]="arm arm64 ppc64le"
["gvisor_runsc_binary"]="arm ppc64le"
["gvisor_containerd_shim_binary"]="arm ppc64le"
["containerd_archive"]="arm"
["skopeo_binary"]="arm"
)
    echo "${binary}_checksums:" | tee --append "$checksums_file"
    for arch in arm arm64 amd64 ppc64le; do
        echo "  $arch:" | tee --append "$checksums_file"
        for version in "${@:2}"; do
            checksum=0
            [[ "${skip_archs[$binary]}" == *"$arch"* ]] || checksum=$(_get_checksum "$binary" "$version" "$arch")
            [[ "$version_exceptions" != *"$binary"* ]] || version=${version#v}
            echo "    $version: $checksum" | tee --append "$checksums_file"
        done
    done
}

function get_krew_archive_checksums() {
    declare -A archs=(
["linux"]="arm arm64 amd64"
["darwin"]="arm64 amd64"
["windows"]="amd64"
)

    echo "krew_archive_checksums:" | tee --append "$checksums_file"
    for os in "${!archs[@]}"; do
        echo "  $os:" | tee --append "$checksums_file"
        for arch in arm arm64 amd64 ppc64le; do
            echo "    $arch:" | tee --append "$checksums_file"
            for version in "$@"; do
                checksum=0
                [[ " ${archs[$os]} " != *" $arch "* ]] || checksum=$(_get_checksum "krew_archive" "$version" "$arch" "$os")
                echo "      $version: $checksum" | tee --append "$checksums_file"
            done
        done
    done
}

function get_calico_crds_archive_checksums() {
    echo "calico_crds_archive_checksums:" | tee --append "$checksums_file"
    for version in "$@"; do
        echo "  $version: $(_get_checksum "calico_crds_archive" "$version")" | tee --append "$checksums_file"
    done
}

function get_containerd_archive_checksums() {
    declare -A support_version_history=(
["arm"]="2"
["arm64"]="1.6.0"
["amd64"]="1.5.5"
["ppc64le"]="1.6.7"
)

    echo "containerd_archive_checksums:" | tee --append "$checksums_file"
    for arch in arm arm64 amd64 ppc64le; do
        echo "  $arch:" | tee --append "$checksums_file"
        for version in "${@}"; do
            _vercmp "${version#v}" '>=' "${support_version_history[$arch]}" && checksum=$(_get_checksum "containerd_archive" "$version" "$arch") || checksum=0
            echo "    ${version#v}: $checksum" | tee --append "$checksums_file"
        done
    done
}

function get_k8s_checksums() {
    local binary=$1

    echo "${binary}_checksums:" | tee --append "$checksums_file"
    echo "  arm:" | tee --append "$checksums_file"
    for version in "${@:2}"; do
        _vercmp "${version#v}" '<' "1.27" && checksum=$(_get_checksum "$binary" "$version" "arm") || checksum=0
        echo "    ${version}: $checksum" | tee --append "$checksums_file"
    done
    for arch in arm64 amd64 ppc64le; do
        echo "  $arch:" | tee --append "$checksums_file"
        for version in "${@:2}"; do
            echo "    ${version}: $(_get_checksum "$binary" "$version" "$arch")" | tee --append "$checksums_file"
        done
    done
}

function get_crictl_checksums() {
    local binary=$1

    echo "${binary}_checksums:" | tee --append "$checksums_file"
    echo "  arm:" | tee --append "$checksums_file"
    for version in "${@:2}"; do
        _vercmp "${version#v}" '<' "1.29" && checksum=$(_get_checksum "$binary" "$version" "arm") || checksum=0
        echo "    ${version}: $checksum" | tee --append "$checksums_file"
    done
    for arch in arm64 amd64 ppc64le; do
        echo "  $arch:" | tee --append "$checksums_file"
        for version in "${@:2}"; do
            echo "    ${version}: $(_get_checksum "$binary" "$version" "$arch")" | tee --append "$checksums_file"
        done
    done
}

# Note: kata changed their arch starting at version 3.2.0
function get_arch_kata() {
    local version="${1}"
    local arch="${2}"

    if _vercmp "${version}" '<' '3.2.0'; then
        echo "${arch//amd64/x86_64}"
    else
        echo "${arch}"
    fi
}

function _get_checksum() {
    local binary="$1"
    local version="$2"
    local arch="${3:-amd64}"
    local os="${4:-linux}"
    local target="$downloads_folder/$binary/$version-$os-$arch"
    readonly github_url="https://github.com"
    readonly github_releases_url="$github_url/%s/releases/download/$version/%s"
    readonly github_archive_url="$github_url/%s/archive/%s"
    readonly google_url="https://storage.googleapis.com"
    readonly release_url="https://dl.k8s.io"
    readonly k8s_url="$release_url/release/$version/bin/$os/$arch/%s.sha256"

    # Download URLs
    declare -A urls=(
["crictl"]="$(printf "$github_releases_url" "kubernetes-sigs/cri-tools" "crictl-$version-$os-$arch.tar.gz.sha256")"
["crio_archive"]="$google_url/cri-o/artifacts/cri-o.$arch.$version.tar.gz.sha256sum"
["kubelet"]="$(printf "$k8s_url" "kubelet")"
["kubectl"]="$(printf "$k8s_url" "kubectl")"
["kubeadm"]="$(printf "$k8s_url" "kubeadm")"
["etcd_binary"]="$(printf "$github_releases_url" "etcd-io/etcd" "etcd-$version-$os-$arch.tar.gz")"
["cni_binary"]="$(printf "$github_releases_url" "containernetworking/plugins" "cni-plugins-$os-$arch-$version.tgz.sha256")"
["calicoctl_binary"]="$(printf "$github_releases_url" "projectcalico/calico" "calicoctl-$os-$arch")"
["ciliumcli_binary"]="$(printf "$github_releases_url" "cilium/cilium-cli" "cilium-$os-$arch.tar.gz.sha256sum")"
["calico_crds_archive"]="$(printf "$github_archive_url" "projectcalico/calico" "$version.tar.gz")"
["krew_archive"]="$(printf "$github_releases_url" "kubernetes-sigs/krew" "krew-${os}_$arch.tar.gz")"
["helm_archive"]="https://get.helm.sh/helm-$version-$os-$arch.tar.gz"
["cri_dockerd_archive"]="$(printf "$github_releases_url" "Mirantis/cri-dockerd" "cri-dockerd-${version#v}.$arch.tgz")"
["runc"]="$(printf "$github_releases_url" "opencontainers/runc" "runc.sha256sum")"
["crun"]="$(printf "$github_releases_url" "containers/crun" "crun-$version-$os-$arch")"
["youki"]="$(printf "$github_releases_url" "containers/youki" "youki_$([ $version == "v0.0.1" ] && echo "v0_0_1" || echo "${version#v}" | sed 's|\.|_|g')_$os.tar.gz")"
["kata_containers_binary"]="$(printf "$github_releases_url" "kata-containers/kata-containers" "kata-static-$version-$(get_arch_kata "${version}" "${arch}").tar.xz")"
["gvisor_runsc_binary"]="$(printf "$google_url/gvisor/releases/release/$version/%s/runsc" "$(echo "$arch" | sed -e 's/amd64/x86_64/' -e 's/arm64/aarch64/')")"
["gvisor_containerd_shim_binary"]="$(printf "$google_url/gvisor/releases/release/$version/%s/containerd-shim-runsc-v1" "$(echo "$arch" | sed -e 's/amd64/x86_64/' -e 's/arm64/aarch64/')")"
["nerdctl_archive"]="$(printf "$github_releases_url" "containerd/nerdctl" "nerdctl-${version#v}-$os-$([ "$arch" == "arm" ] && echo "arm-v7" || echo "$arch" ).tar.gz")"
["containerd_archive"]="$(printf "$github_releases_url" "containerd/containerd" "containerd-${version#v}-$os-$arch.tar.gz.sha256sum")"
["skopeo_binary"]="$(printf "$github_releases_url" "lework/skopeo-binary" "skopeo-$os-$arch.sha256")"
["yq"]="$(printf "$github_releases_url" "mikefarah/yq" "yq_${os}_$arch")"
)

    mkdir -p "$(dirname $target)"
    [ -f "$target" ] || curl -LfSs -o "${target}" "${urls[$binary]}"
    if [ ! -f "$target" ]; then
        echo "$target can't be downloaded" >&2
        echo 0
        return
    fi
    if echo "${urls[$binary]}" | grep -qi sha256sum; then
        local hashes="$(cat "${target}")"
        if [ "$(echo "${hashes}" | wc -l)" -gt 1 ]; then
            hashes="$(echo "${hashes}" | grep -- "${arch}")"
        fi
        if [ "$(echo "${hashes}" | wc -l)" -gt 1 ]; then
            hashes="$(echo "${hashes}" | grep -- "${os}")"
        fi
        if [ "$(echo "${hashes}" | wc -l)" -gt 1 ]; then
            echo "more than 1 hash" >&2
            echo "${hashes}" >&2
            exit 1
        fi
        echo "${hashes}" | awk '{print $1}'
    elif echo "${urls[$binary]}" | grep -qi sha256; then
        cat "${target}" | awk '{print $1}'
    else
        sha256sum ${target} | awk '{print $1}'
    fi
}

mkdir -p "$(dirname "$checksums_file")"
echo "---" | tee "$checksums_file"
get_crictl_checksums crictl $(get_versions github_tags kubernetes-sigs/cri-tools min_version "${kube_min_version}")
get_checksums crio_archive $(get_versions github_tags cri-o/cri-o min_version "${kube_min_version}")
kubernetes_versions=$(get_versions github_tags kubernetes/kubernetes min_version "${kube_min_version}")
echo "# Checksum" | tee --append "$checksums_file"
echo "# Kubernetes versions above Kubespray's current target version are untested and should be used with caution." | tee --append "$checksums_file"
get_k8s_checksums kubelet $kubernetes_versions
get_checksums kubectl $kubernetes_versions
get_k8s_checksums kubeadm $kubernetes_versions
get_checksums etcd_binary $(get_versions github_tags etcd-io/etcd)
get_checksums cni_binary $(get_versions github_tags containernetworking/plugins)
calico_versions=$(get_versions github_tags projectcalico/calico limit_version 20)
get_checksums calicoctl_binary $calico_versions
get_checksums ciliumcli_binary $(get_versions github_tags cilium/cilium-cli limit_version 10)
get_calico_crds_archive_checksums $calico_versions
get_krew_archive_checksums $(get_versions github_tags kubernetes-sigs/krew limit_version 2)
get_checksums helm_archive $(get_versions github_tags helm/helm)
get_checksums cri_dockerd_archive $(get_versions github_tags Mirantis/cri-dockerd)
get_checksums runc $(get_versions github_tags opencontainers/runc limit_version 5)
get_checksums crun $(get_versions github_tags containers/crun)
get_checksums youki $(get_versions github_tags containers/youki)
get_checksums kata_containers_binary $(get_versions github_tags kata-containers/kata-containers)
gvisor_versions=$(get_versions github_tags google/gvisor gvisor_version_filter)
get_checksums gvisor_runsc_binary $gvisor_versions
get_checksums gvisor_containerd_shim_binary $gvisor_versions
get_checksums nerdctl_archive $(get_versions github_tags containerd/nerdctl)
get_containerd_archive_checksums $(get_versions github_tags containerd/containerd limit_version 30)
get_checksums skopeo_binary $(get_versions github_tags lework/skopeo-binary)
get_checksums yq $(get_versions github_tags mikefarah/yq)
