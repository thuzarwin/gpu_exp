#define TIMER_OK
//#define BLOCK_SIZE 256

#include "../include/wb.h"

#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <stdio.h>

// Compute C = A * B
__global__ 
void matrixMultiply(float *A, float *B, float *C, int numARows,
    int numAColumns, int numBRows, int numBColumns,
    int numCRows, int numCColumns) {
    //@@ Insert code to implement matrix multiplication here
    int colCIndex = blockIdx.x * blockDim.x + threadIdx.x;
    int rowCIndex = blockIdx.y * blockDim.y + threadIdx.y;
    float sum = 0;

    if ((colCIndex < numCColumns) && (rowCIndex < numCRows)) {
        for (int i = 0; i < numAColumns; i++) {
            sum += A[rowCIndex * numAColumns + i] * B[i * numBColumns + colCIndex];
        }
        C[rowCIndex * numCColumns + colCIndex] = sum;
    }
}

int main(int argc, char **argv) {
    wbArg_t args;
    float *hostA; // The A matrix
    float *hostB; // The B matrix
    float *hostC; // The output C matrix
    float *deviceA;
    float *deviceB;
    float *deviceC;
    int numARows;    // number of rows in the matrix A
    int numAColumns; // number of columns in the matrix A
    int numBRows;    // number of rows in the matrix B
    int numBColumns; // number of columns in the matrix B
    int numCRows;    // number of rows in the matrix C (you have to set this)
    int numCColumns; // number of columns in the matrix C (you have to set this)
    int inputByteSizeC;
    args = wbArg_read(argc, argv);

    wbTime_start(Generic, "Importing data and creating memory on host");
    hostA = (float *)wbImport(wbArg_getInputFile(args, 0), &numARows, &numAColumns);
    hostB = (float *)wbImport(wbArg_getInputFile(args, 1), &numBRows, &numBColumns);
    //@@ Set numCRows and numCColumns
    numCRows = numARows;
    numCColumns = numBColumns;
    //@@ Allocate the hostC matrix
    hostC = (float *)malloc(numCRows * numCColumns * sizeof(float));
    wbTime_stop(Generic, "Importing data and creating memory on host");

    wbLog(TRACE, "The dimensions of A are ", numARows, " x ", numAColumns);
    wbLog(TRACE, "The dimensions of B are ", numBRows, " x ", numBColumns);

    wbTime_start(GPU, "Allocating GPU memory.");
    //@@ Allocate GPU memory here
    int byteSizeA = numARows * numAColumns * sizeof(float);
    int byteSizeB = numBRows * numBColumns * sizeof(float);
    int byteSizeC = numCRows * numCColumns * sizeof(float);
    wbCheck(cudaMalloc(&deviceA, byteSizeA), "cudaMalloc(&deviceA");
    wbCheck(cudaMalloc(&deviceB, byteSizeB), "cudaMalloc(&deviceB");
    wbCheck(cudaMalloc(&deviceC, byteSizeC), "cudaMalloc(&deviceC");
    wbTime_stop(GPU, "Allocating GPU memory.");

    wbTime_start(GPU, "Copying input memory to the GPU.");
    //@@ Copy memory to the GPU here
    wbCheck(cudaMemcpy(deviceA, hostA, byteSizeA, cudaMemcpyHostToDevice), "cudaMemcpy(deviceA");
    wbCheck(cudaMemcpy(deviceB, hostB, byteSizeB, cudaMemcpyHostToDevice), "cudaMemcpy(deviceB");
    wbCheck(cudaMemcpy(deviceC, hostC, byteSizeC, cudaMemcpyHostToDevice), "cudaMemcpy(deviceC");
    wbTime_stop(GPU, "Copying input memory to the GPU.");

    //@@ Initialize the grid and block dimensions here
    dim3 DimBlock(32, 32, 1);
    dim3 DimGrid(numCColumns / DimBlock.x + 1, numCRows / DimBlock.y + 1, 1);

    wbTime_start(Compute, "Performing CUDA computation");
    //@@ Launch the GPU Kernel here
    matrixMultiply <<<DimGrid, DimBlock >>> (deviceA, deviceB, deviceC, 
        numARows, numAColumns, numBRows, numBColumns, numCRows, numCColumns);
    cudaDeviceSynchronize();
    wbTime_stop(Compute, "Performing CUDA computation");

    wbTime_start(Copy, "Copying output memory to the CPU");
    //@@ Copy the GPU memory back to the CPU here
    wbCheck(cudaMemcpy(hostA, deviceA, byteSizeA, cudaMemcpyDeviceToHost), "cudaMemcpy(deviceA");
    wbCheck(cudaMemcpy(hostB, deviceB, byteSizeB, cudaMemcpyDeviceToHost), "cudaMemcpy(deviceB");
    wbCheck(cudaMemcpy(hostC, deviceC, byteSizeC, cudaMemcpyDeviceToHost), "cudaMemcpy(deviceC");
    wbTime_stop(Copy, "Copying output memory to the CPU");

    wbTime_start(GPU, "Freeing GPU Memory");
    //@@ Free the GPU memory here
    wbCheck(cudaFree(deviceA), "cudaFree(deviceA");
    wbCheck(cudaFree(deviceB), "cudaFree(deviceB");
    wbCheck(cudaFree(deviceC), "cudaFree(deviceC");
    wbTime_stop(GPU, "Freeing GPU Memory");

    wbSolution(args, hostC, numCRows, numCColumns);

    free(hostA);
    free(hostB);
    free(hostC);

    return 0;
}
