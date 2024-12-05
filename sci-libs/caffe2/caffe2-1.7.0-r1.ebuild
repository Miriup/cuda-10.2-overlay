# Copyright 2022-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Python 3.11 has C-API changes pulling in too many patches and 
#        3.9 is not supported according to src_configure() output
PYTHON_COMPAT=( python3_10 )
inherit python-single-r1 cmake cuda flag-o-matic git-r3

MYPN=pytorch
MYP=${MYPN}-${PV}

DESCRIPTION="A deep learning framework"
HOMEPAGE="https://pytorch.org/"
#SRC_URI="https://github.com/pytorch/${MYPN}/archive/refs/tags/v${PV}.tar.gz
#	-> ${MYP}.tar.gz"
EGIT_REPO_URI="https://github.com/pytorch/${MYPN}"
EGIT_BRANCH="main"
EGIT_COMMIT="v${PV}"
EGIT_CLONE_TYPE="shallow"	# libeigen/eigen is large
EGIT_CHECKOUT_DIR="${MYP}"
# Use from system, see src_configure
EGIT_SUBMODULES=( '*' "-third_party/eigen" "-third_party/pthreadpool"  "-third_party/gloo" "-third_party/onnx" "-third_party/sleef" "-third_party/fmt" )
# Dirk: github repo is broken and I don't understand why the COMMIT ID differs.
EGIT_OVERRIDE_REPO_EIGENTEAM_EIGEN_GIT_MIRROR=https://gitlab.com/libeigen/eigen.git
EGIT_OVERRIDE_COMMIT_EIGENTEAM_EIGEN_GIT_MIRROR=71429883ee41689fd657cdca824459f38ae53423
EGIT_OVERRIDE_COMMIT_ONNX_ONNX=9d64613a09eb813b25a18dd4d527319df18cb28e	# in case system-onnx doesn't work

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64"
IUSE="cuda distributed fbgemm ffmpeg gloo mpi nnpack +numpy opencl opencv openmp qnnpack tensorpipe xnnpack"
RESTRICT="test"
REQUIRED_USE="
	${PYTHON_REQUIRED_USE}
	ffmpeg? ( opencv )
	mpi? ( distributed )
	tensorpipe? ( distributed )
	gloo? ( distributed )
" # ?? ( cuda rocm )

# CUDA 12 not supported yet: https://github.com/pytorch/pytorch/issues/91122
RDEPEND="
	${PYTHON_DEPS}
	dev-cpp/gflags:=
	>=dev-cpp/glog-0.5.0
	dev-libs/cpuinfo
	dev-libs/libfmt
	<dev-libs/protobuf-21.13:=
	dev-libs/pthreadpool
	<dev-libs/sleef-3.7
	sci-libs/lapack
	sci-libs/onnx
	sci-libs/foxi
	cuda? (
		=dev-libs/cudnn-8*
		dev-libs/cudnn-frontend:0/8
		=dev-util/nvidia-cuda-toolkit-10.2*:=[profiler]
	)
	fbgemm? ( dev-libs/FBGEMM )
	ffmpeg? ( media-video/ffmpeg:= )
	gloo? ( sci-libs/gloo[cuda?] )
	mpi? ( sys-cluster/openmpi )
	nnpack? ( sci-libs/NNPACK )
	numpy? ( $(python_gen_cond_dep '
		<dev-python/numpy-2.0[${PYTHON_USEDEP}]
		') )
	opencl? ( virtual/opencl )
	opencv? ( media-libs/opencv:= )
	qnnpack? ( sci-libs/QNNPACK )
	tensorpipe? ( sci-libs/tensorpipe )
	xnnpack? ( sci-libs/XNNPACK )
"
DEPEND="
	${RDEPEND}
	dev-cpp/eigen
	cuda? ( dev-libs/cutlass )
	dev-libs/psimd
	dev-libs/FP16
	dev-libs/FXdiv
	dev-libs/pocketfft
	dev-libs/flatbuffers
	sci-libs/kineto
	$(python_gen_cond_dep '
		dev-python/pyyaml[${PYTHON_USEDEP}]
		dev-python/pybind11[${PYTHON_USEDEP}]
	')
"
BDEPEND="
	sys-devel/gcc:8.5.0
"

S="${WORKDIR}"/${MYP}

PATCHES=(
	#"${FILESDIR}"/${PF}-gentoo.patch
	#"${FILESDIR}"/${PF}-install-dirs.patch
	#"${FILESDIR}"/${PF}-glog-0.6.0.patch
	#"${FILESDIR}"/${PF}-clang.patch
	#"${FILESDIR}"/${PF}-tensorpipe.patch
)

src_prepare() {
	filter-lto #bug 862672
	sed -i \
		-e "/third_party\/gloo/d" \
		cmake/Dependencies.cmake \
		|| die
	cmake_src_prepare
	#pushd torch/csrc/jit/serialization || die
	#flatc --cpp --gen-mutable --scoped-enums mobile_bytecode.fbs || die
	#popd
}

src_configure() {
	if use cuda && [[ -z ${TORCH_CUDA_ARCH_LIST} ]]; then
		ewarn "WARNING: caffe2 is being built with its default CUDA compute capabilities: 3.5 and 7.0."
		ewarn "These may not be optimal for your GPU."
		ewarn ""
		ewarn "To configure caffe2 with the CUDA compute capability that is optimal for your GPU,"
		ewarn "set TORCH_CUDA_ARCH_LIST in your make.conf, and re-emerge caffe2."
		ewarn "For example, to use CUDA capability 7.5 & 3.5, add: TORCH_CUDA_ARCH_LIST=7.5,3.5"
		ewarn "For a Maxwell model GPU, an example value would be: TORCH_CUDA_ARCH_LIST=Maxwell"
		ewarn ""
		ewarn "You can look up your GPU's CUDA compute capability at https://developer.nvidia.com/cuda-gpus"
		ewarn "or by running /opt/cuda/extras/demo_suite/deviceQuery | grep 'CUDA Capability'"
	fi

	local mycmakeargs=(
		-DBUILD_CUSTOM_PROTOBUF=OFF
		-DBUILD_SHARED_LIBS=ON

		-DUSE_CCACHE=OFF
		-DUSE_CUDA=$(usex cuda)
		-DUSE_CUDNN=$(usex cuda)
		-DUSE_FAST_NVCC=$(usex cuda)
		-DTORCH_CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST:-3.5 7.0}"
		-DUSE_DISTRIBUTED=$(usex distributed)
		-DUSE_MPI=$(usex mpi)
		-DUSE_FAKELOWP=OFF
		-DUSE_FBGEMM=$(usex fbgemm)
		-DUSE_FFMPEG=$(usex ffmpeg)
		-DUSE_GFLAGS=ON
		-DUSE_GLOG=ON
		-DUSE_GLOO=$(usex gloo)
		-DUSE_KINETO=OFF # TODO
		-DUSE_LEVELDB=OFF
		-DUSE_MAGMA=OFF # TODO: In GURU as sci-libs/magma
		-DUSE_MKLDNN=OFF
		-DUSE_NCCL=OFF # TODO: NVIDIA Collective Communication Library
		-DUSE_NNPACK=$(usex nnpack)
		-DUSE_QNNPACK=$(usex qnnpack)
		-DUSE_XNNPACK=$(usex xnnpack)
		-DUSE_SYSTEM_XNNPACK=$(usex xnnpack)
		-DUSE_TENSORPIPE=$(usex tensorpipe)
		-DUSE_PYTORCH_QNNPACK=OFF
		-DUSE_NUMPY=$(usex numpy)
		-DUSE_OPENCL=$(usex opencl)
		-DUSE_OPENCV=$(usex opencv)
		-DUSE_OPENMP=$(usex openmp)
		-DUSE_ROCM=OFF # TODO
		-DUSE_SYSTEM_CPUINFO=ON
		-DUSE_SYSTEM_PYBIND11=ON
		-DUSE_UCC=OFF
		-DUSE_VALGRIND=OFF
		-DPYBIND11_PYTHON_VERSION="${EPYTHON#python}"
		-DPYTHON_EXECUTABLE="${PYTHON}"
		-DUSE_ITT=OFF
		-DBLAS=Eigen # avoid the use of MKL, if found on the system
		-DUSE_SYSTEM_EIGEN_INSTALL=ON
		-DUSE_SYSTEM_PTHREADPOOL=ON
		-DUSE_SYSTEM_FXDIV=ON
		-DUSE_SYSTEM_FP16=ON
		-DUSE_SYSTEM_GLOO=ON
		-DUSE_SYSTEM_ONNX=ON
		-DUSE_SYSTEM_SLEEF=ON

		-Wno-dev
		-DTORCH_INSTALL_LIB_DIR="${EPREFIX}"/usr/$(get_libdir)
		-DLIBSHM_INSTALL_LIB_SUBDIR="${EPREFIX}"/usr/$(get_libdir)
	)

	if use cuda; then
		addpredict "/dev/nvidiactl" # bug 867706
		addpredict "/dev/char"

		mycmakeargs+=(
			-DCMAKE_CUDA_FLAGS="$(cuda_gccdir -f | tr -d \")"
			-DCMAKE_CUDA_HOST_COMPILER=/usr/bin/x86_64-pc-linux-gnu-g++-8.5.0
		)
	fi
	cmake_src_configure
}

src_install() {
	cmake_src_install

	insinto "/var/lib/${PN}"
	doins "${BUILD_DIR}"/CMakeCache.txt

	rm -rf python
	mkdir -p python/torch/include || die
	mv "${ED}"/usr/lib/python*/site-packages/caffe2 python/ || die
	mv "${ED}"/usr/include/torch python/torch/include || die
	cp torch/version.py python/torch/ || die
	rm -rf "${ED}"/var/tmp || die
	python_domodule python/caffe2
	python_domodule python/torch
}
