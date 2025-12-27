# podman build -t clusterfile-editor -f apps/editor/Containerfile .
# podman tag localhost/clusterfile-editor  quay.io/dds/clusterfile-editor
# podman push quay.io/dds/clusterfile-editor
podman run -p 8000:8000 -v $(pwd)/../../templates:/app/templates \
                        -v $(pwd)/../../data:/app/samples \
                        -v $(pwd)/../../schema:/app/schema quay.io/dds/clusterfile-editor
