# Docker Private Registry (SeaweedFS S3 Backend)

This documentation guides you on how to manage and inspect a Private Registry with SeaweedFS S3 as the storage backend.

---

## 1. View and Manage Images in Registry


### 1.1 By Curl
* **List all repositories (available images):**

  ```bash
  # curl -s -X GET http://<service-registry>.<namespace>.svc.cluster.local:5000/v2/_catalog | jq .
  ```
  Example:

  ```bash
  curl -s -X GET http://registry-docker-registry-service.registry.svc.cluster.local:5000/v2/_catalog | jq .
  ```
  ---
* **List tags of a specific image:**

  ```bash
  # curl -X GET http://<service-registry>.<namespace>.svc.cluster.local:5000/v2/<image_name>/tags/list
  ```
  Example:

  ```bash
  curl -s -X GET http://private-registry-docker-registry-service.private-registry.svc.cluster.local:5000/v2/<image_name>/tags/list
  ```

### 1.2 By GUI of seaweedfs
* Expose NodePort seaweedfs filer 
* View images on GUI at folder ***http://<Node_IP>:<Node_Port>/buckets/registry/docker/registry/v2/repositories/***
## 2. Pull Images using crictl

* **Pull image**

  ```bash
  crictl pull private.registry/svtechnmaa/<image_name>:<tag>
  ```

  ***Note:*** `private.registry` is a *short name/alias* configured in containerd that points to the actual registry server at `registry-docker-registry-service.registry.svc.cluster.local:5000`. 

  **Why this configuration is needed:** By default, containerd tries to connect to registries using HTTPS. However, this registry runs on HTTP. To allow HTTP connections, you must configure `private.registry` in containerd's configuration file.

  **Configuration example** in `/etc/containerd/certs.d/private.registry/hosts.toml`:
  ```toml
  server = "http://registry-docker-registry-service.registry.svc.cluster.local:5000"
  ```

  This allows you to pull images using the short name without needing to specify the full server address each time.