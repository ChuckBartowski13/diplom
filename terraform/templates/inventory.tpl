[all]
${connection_strings_cp}
${connection_strings_worker}

[kube_control_plane]
${list_cp}

[kube_node]
${list_worker}

[etcd]
${list_cp}

[k8s_cluster:children]
kube_node
kube_control_plane
