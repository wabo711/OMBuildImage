#
# アプリケーションビルド用イメージ作成 
#

# Ubuntu 18.04をベースとする
FROM ubuntu:18.04 AS builder

# タイムゾーンを日本に設定する（タイムゾーン選択回避）
RUN apt-get update && apt-get install -y tzdata
ENV TZ=Asia/Tokyo

# ビルドに必要なパッケージをインストールする
RUN apt-get update && apt-get install -y \
  build-essential autoconf git pkg-config cmake \
  automake libtool curl make g++ g++-9 unzip uuid uuid-dev \
  software-properties-common mosquitto mosquitto-clients zlib1g-dev \
  && add-apt-repository ppa:ubuntu-toolchain-r/test \
  && apt update && apt install -y g++-9-multilib \
  && apt-get clean -y \
  && update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-9 30 \
  && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-9 30

# grpcをビルドして共有ライブラリに登録する
ENV GRPC_RELEASE_TAG v1.27.x
RUN git clone -b ${GRPC_RELEASE_TAG} https://github.com/grpc/grpc /var/local/git/grpc && \
    cd /var/local/git/grpc && \
    git submodule update --init && \
    echo "--- installing protobuf ---" && \
    cd third_party/protobuf && \
    git submodule update --init && \
    ./autogen.sh && ./configure --enable-shared && \
    make -j$(nproc) && make -j$(nproc) check && make install && make clean && ldconfig && \
    echo "--- installing grpc ---" && \
    cd /var/local/git/grpc && \
    make -j$(nproc) && make install && make clean && ldconfig && \
    rm -rf /var/local/git/grpc

# googleTestのインストール
RUN git clone https://github.com/google/googletest.git /var/local/git/gtest \
    && cd /var/local/git/gtest \
    && mkdir build \
    && cd build \
    && cmake .. \
    && make \
    && cp lib/lib*.a /usr/lib \
    && cd /var/local/git/gtest \
    && cp -r googletest/include/gtest /usr/include \
    && cp -r googlemock/include/gmock /usr/include \
    && rm -rf /var/local/git/gtest

# パッケージのupgradeおよびキャッシュファイルの削除
RUN apt-get upgrade -y && apt-get clean -y

