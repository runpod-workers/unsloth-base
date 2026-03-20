ARG CUDA_VERSION=cu1281
FROM runpod/pytorch:1.0.3-${CUDA_VERSION}-torch260-ubuntu2404

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ============================================
# Layer 1: System packages (Node.js for frontend build + runtime oxc-validator)
# ============================================
ARG NODE_MAJOR=22
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - && \
    apt-get install -y --no-install-recommends nodejs=${NODE_MAJOR}.* && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ============================================
# Layer 2: Clone Unsloth repo (pin to specific commit for reproducibility)
# ============================================
ARG UNSLOTH_COMMIT=29270a3726d00c2dd11bb049b61d838e60ef341b
RUN git clone https://github.com/unslothai/unsloth.git /opt/unsloth && \
    cd /opt/unsloth && \
    git checkout ${UNSLOTH_COMMIT}

# ============================================
# Layer 3: Build frontend (React/Vite)
# ============================================
WORKDIR /opt/unsloth/studio/frontend
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi && npx vite build

# ============================================
# Layer 4: Install oxc-validator runtime deps
# ============================================
WORKDIR /opt/unsloth/studio/backend/core/data_recipe/oxc-validator
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi

# ============================================
# Layer 5: Create Python venv and install uv
# ============================================
RUN python3 -m venv /opt/unsloth-venv && \
    /opt/unsloth-venv/bin/pip install --no-cache-dir --upgrade pip && \
    /opt/unsloth-venv/bin/pip install --no-cache-dir uv

# ============================================
# Layer 6: Install Python deps (matching install_python_stack.py order)
# ============================================
ARG TORCH_BACKEND=cu128
ENV VIRTUAL_ENV=/opt/unsloth-venv
ENV PATH="/opt/unsloth-venv/bin:$PATH"
ENV UV_TORCH_BACKEND=${TORCH_BACKEND}
WORKDIR /opt/unsloth/studio/backend/requirements

# Step 1: Base packages
RUN /opt/unsloth-venv/bin/uv pip install --no-cache-dir \
    -c single-env/constraints.txt \
    -r base.txt

# Step 2: Extra dependencies
RUN /opt/unsloth-venv/bin/uv pip install --no-cache-dir \
    -c single-env/constraints.txt \
    -r extras.txt

# Step 3: Extra codecs (no-deps)
RUN /opt/unsloth-venv/bin/uv pip install --no-cache-dir --no-deps \
    -c single-env/constraints.txt \
    -r extras-no-deps.txt

# Step 4: Overrides (force-reinstall)
RUN /opt/unsloth-venv/bin/uv pip install --no-cache-dir --reinstall \
    -c single-env/constraints.txt \
    -r overrides.txt

# Step 5: Triton kernels (no-deps, no constraints)
RUN /opt/unsloth-venv/bin/uv pip install --no-cache-dir --no-deps \
    -r triton-kernels.txt

# Step 6: Studio dependencies
RUN /opt/unsloth-venv/bin/uv pip install --no-cache-dir \
    -c single-env/constraints.txt \
    -r studio.txt

# Step 7: Data designer deps
RUN /opt/unsloth-venv/bin/uv pip install --no-cache-dir \
    -c single-env/constraints.txt \
    -r single-env/data-designer-deps.txt

# Step 8: Data designer packages (no-deps)
RUN /opt/unsloth-venv/bin/uv pip install --no-cache-dir --no-deps \
    -c single-env/constraints.txt \
    -r single-env/data-designer.txt

# ============================================
# Layer 7: Install local plugins (no-deps)
# ============================================
RUN /opt/unsloth-venv/bin/pip install --no-cache-dir --no-deps \
    /opt/unsloth/studio/backend/plugins/data-designer-unstructured-seed

# ============================================
# Layer 8: Patch metadata (fixes package version conflicts)
# ============================================
RUN /opt/unsloth-venv/bin/python single-env/patch_metadata.py

# ============================================
# Layer 9: Install Unsloth (editable)
# ============================================
RUN /opt/unsloth-venv/bin/pip install --no-cache-dir -e /opt/unsloth

# ============================================
# Layer 10: Create transformers 5.x overlay (flat --target dir, NOT a venv)
# Studio prepends this to sys.path for T5 worker subprocesses
# ============================================
RUN /opt/unsloth-venv/bin/pip install --no-cache-dir --no-deps \
    --target /opt/unsloth-venv-t5 \
    transformers==5.3.0 huggingface_hub==1.7.1 hf_xet==1.4.2 && \
    /opt/unsloth-venv/bin/pip install --no-cache-dir \
    --target /opt/unsloth-venv-t5 \
    tiktoken

# ============================================
# Layer 11: Copy start script
# ============================================
COPY start.sh /start.sh
RUN chmod +x /start.sh

# ============================================
# Metadata
# ============================================
EXPOSE 8000 8888 22

ENV PYTHONUNBUFFERED=1

# Allow container to start on hosts with older CUDA 12.x drivers
ENV NVIDIA_REQUIRE_CUDA=""
ENV NVIDIA_DISABLE_REQUIRE=true
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all

WORKDIR /workspace

CMD ["/start.sh"]
