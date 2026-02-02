FROM nvidia/cuda:12.1.0-cudnn8-devel-ubuntu20.04

LABEL maintainer="zh_zheng2003@outlook.com"

# 环境变量集中定义
ENV DEBIAN_FRONTEND=noninteractive \
    PATH="/opt/conda/bin:/usr/local/cuda-12.1/bin:${PATH}" \
    CUDA_HOME=/usr/local/cuda \
    LD_LIBRARY_PATH="/usr/local/cuda-12.1/lib64:${LD_LIBRARY_PATH}" \
    SHELL=/bin/bash

# 系统依赖安装 - 合并所有 apt 操作并清理缓存
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget curl man git less openssl libssl-dev unzip unar \
    build-essential aria2 openssh-server tmux vim ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# 安装 ninja
RUN wget -q https://github.com/ninja-build/ninja/releases/download/v1.10.2/ninja-linux.zip \
    && unzip ninja-linux.zip -d /usr/local/bin/ \
    && rm -f ninja-linux.zip \
    && update-alternatives --install /usr/bin/ninja ninja /usr/local/bin/ninja 1 --force

# 安装 vim 配置
RUN git clone --depth=1 https://github.com/amix/vimrc.git ~/.vim_runtime \
    && sh ~/.vim_runtime/install_awesome_vimrc.sh \
    && echo "set number" >> ~/.vimrc

# 安装 azcopy
RUN wget -q https://aka.ms/downloadazcopy-v10-linux -O azcopy.tar \
    && tar -xf azcopy.tar \
    && cp ./azcopy_linux_amd64_*/azcopy /usr/bin/ \
    && chmod 755 /usr/bin/azcopy \
    && rm -rf azcopy.tar ./azcopy_linux_amd64_*/

# 安装 blobfuse
RUN wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends blobfuse \
    && rm -f packages-microsoft-prod.deb \
    && rm -rf /var/lib/apt/lists/*

# 安装 conda
RUN wget -q https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh \
    && bash miniconda.sh -b -p /opt/conda \
    && rm -f miniconda.sh \
    && ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh \
    && echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc \
    && /opt/conda/bin/conda clean -afy

SHELL ["/bin/bash", "--login", "-c"]

# 创建 conda 环境并安装 Python 依赖
RUN conda init bash \
    && conda config --remove channels defaults || true \
    && conda config --add channels conda-forge \
    && conda config --set channel_priority strict \
    && conda create -n ditmem python=3.10 -c conda-forge --override-channels -y \
    && conda activate ditmem \
    && echo "conda activate ditmem" >> ~/.bashrc \
    # 安装 PyTorch
    && pip install --no-cache-dir \
        torch==2.5.0 torchvision==0.20.0 torchaudio==2.5.0 \
        --index-url https://download.pytorch.org/whl/cu121 \
    # 安装其他依赖 - 合并所有 pip install
    && pip install --no-cache-dir \
        transformers==4.57.1 accelerate==1.10.1 deepspeed==0.18.0 \
        peft==0.17.1 triton==3.1.0 opencv-python imageio imageio-ffmpeg \
        pillow einops safetensors tokenizers==0.22.1 sentencepiece \
        hf-xet==1.1.10 modelscope==1.31.0 faiss-cpu==1.12.0 \
        numpy pandas tqdm loguru easydict hjson PyYAML huggingface-hub \
        typing_extensions packaging ftfy gradio streamlit cupy \
        facexlib insightface onnxruntime-gpu \
        wandb openai azure-identity nano_vectordb \
    # 安装 flash-attn (需要 --no-build-isolation)
    && pip install --no-cache-dir flash-attn==2.3.6 --no-build-isolation \
    # 清理 conda 缓存
    && conda clean -afy \
    && rm -rf ~/.cache/pip

CMD ["/bin/bash"]