# Shared Volume Chart



1. Change `storageClass` in `values.yaml` to use seaweedfs or hostpath pv
2. IF: you use host path pv, the host path will be: `/opt/shared/<namespace>/<namespace>-<pv-name>`
3. IF: you use seaweedfs, there are 2 ways to approach the data:
   1. API
      - Filer path: `<namespace>/api/ `
   2. PV mount
      - Filer path: `<namespace>/csi/<namespace>-<pv-name>`
      - Host path: use `mount | grep <namespace>-<pv-name>` to find mount path of the pv on the host. It will be something like `/var/lib/kubelet/plugins/kubernetes.io/csi/seaweedfs-csi-driver/<random-id>/globalmount`

4. Tree level of Seaweedfs Filer

```
+--- <namespace_1>
|   +--- api
	|   +--- <data_uploaded_via_api>
|   +--- csi
	|   +--- <namespace_1>-<pv-name>
+--- <namespace_2>
|   +--- api
	|   +--- <data_uploaded_via_api>
|   +--- csi
	|   +--- <namespace_2>-<pv-name>
```

