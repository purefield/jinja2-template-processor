cd apps/editor
podman build -t clusterfile-editor .
podman run -p 8000:8000 -v $(pwd)/../../templates:/app/templates \
                        -v $(pwd)/../../data:/app/samples \
                        -v $(pwd)/../../schema:/app/schema clusterfile-editor

