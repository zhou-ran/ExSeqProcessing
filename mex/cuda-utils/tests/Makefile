# SYNOPSIS:
#
#   make [all]  - makes everything.
#   make TARGET - makes the given target.
#   make clean  - removes all files generated by make.

.SUFFIXES: .cu

GTEST_DIR=/mp/nas1/share/lib/googletest/googletest

CUDA_INC=/usr/local/cuda/include
CUDA_LIB=/usr/local/cuda/lib64

SPDLOG_DIR=../../include

TESTS=gtest_cudautils

GTEST_HEADERS=$(GTEST_DIR)/include/gtest/*.h \
              $(GTEST_DIR)/include/gtest/internal/*.h
GTEST_LIBS=$(GTEST_DIR)/libgtest_main.a $(GTEST_DIR)/libgtest.a

CPPFLAGS+=-isystem $(GTEST_DIR)/include -I$(SPDLOG_DIR) -I..
CXXFLAGS+=-g -std=c++11 -Wall -Wextra -pthread
NVCCFLAGS=-g -std=c++11 --gpu-architecture=sm_61


all : $(TESTS)

clean :
	rm -f $(TESTS) *.o


gtest_cudautils.o : gtest_cudautils.cpp $(GTEST_HEADERS)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c gtest_cudautils.cpp

gtest_cudautils : gtest_cudautils.o ../libcudautils.a
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $(GTEST_LIBS) -lpthread $^ -o $@ -L$(CUDA_LIB) -lcudart

