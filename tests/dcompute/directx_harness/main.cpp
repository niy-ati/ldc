// Minimal D3D12 compute harness for LDC-generated DXIL kernels.
//
// Loads a .dxil blob, binds a RawBuffer SRV at (space=0, reg=0) with the packed
// kernel argument struct (currently: one i32 GPU VA), dispatches the wrapper
// entry (*_kernel), and readbacks the target buffer.
//
// This is intentionally small — meant to debug the provisional arg-buffer ABI
// before committing to it (see targetDirectX.cpp / Vulkan wrapper).

#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>

#include <d3d12.h>
#include <dxgi1_4.h>
#include <wrl/client.h>

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <optional>
#include <stdexcept>
#include <string>
#include <vector>

using Microsoft::WRL::ComPtr;

namespace {

struct ArgsBlob {
  UINT32 outputGpuVa;
};

#define HR(expr)                                                                 \
  do {                                                                           \
    const HRESULT _hr = (expr);                                                  \
    if (FAILED(_hr)) {                                                           \
      std::fprintf(stderr, "HRESULT 0x%08lX at %s:%d\n", (unsigned long)_hr,   \
                   __FILE__, __LINE__);                                          \
      return 1;                                                                  \
    }                                                                            \
  } while (0)

#define HR_THROW(expr)                                                             \
  do {                                                                             \
    const HRESULT _hr = (expr);                                                    \
    if (FAILED(_hr)) {                                                             \
      throw std::runtime_error("HRESULT failure");                                 \
    }                                                                              \
  } while (0)

std::vector<uint8_t> readFile(const char *path) {
  std::ifstream in(path, std::ios::binary);
  if (!in)
    throw std::runtime_error(std::string("failed to open ") + path);
  return std::vector<uint8_t>((std::istreambuf_iterator<char>(in)),
                              std::istreambuf_iterator<char>());
}

std::optional<std::vector<uint8_t>> extractDxContainerPart(
    const std::vector<uint8_t> &dxbc, const char *partName) {
  if (dxbc.size() < 32)
    return std::nullopt;
  const uint32_t partCount =
      *reinterpret_cast<const uint32_t *>(dxbc.data() + 28);
  for (uint32_t i = 0; i < partCount; ++i) {
    const size_t tableOff = 32 + static_cast<size_t>(i) * 4;
    if (tableOff + 4 > dxbc.size())
      return std::nullopt;
    const uint32_t off =
        *reinterpret_cast<const uint32_t *>(dxbc.data() + tableOff);
    if (off + 8 > dxbc.size())
      return std::nullopt;
    if (std::memcmp(dxbc.data() + off, partName, 4) != 0)
      continue;
    const uint32_t size =
        *reinterpret_cast<const uint32_t *>(dxbc.data() + off + 4);
    const size_t dataOff = off + 8;
    if (dataOff + size > dxbc.size())
      return std::nullopt;
    return std::vector<uint8_t>(dxbc.begin() + dataOff,
                                dxbc.begin() + dataOff + size);
  }
  return std::nullopt;
}

void maybeEnableDebugLayer() {
  ComPtr<ID3D12Debug> debug;
  if (SUCCEEDED(D3D12GetDebugInterface(IID_PPV_ARGS(&debug))))
    debug->EnableDebugLayer();
}

void printUsage(const char *argv0) {
  std::fprintf(stderr,
               "Usage: %s <kernel.dxil> <entry_point> [expected_float]\n"
               "\n"
               "  entry_point  Exported *_kernel symbol from LDC IR (see .ll)\n"
               "  expected     Optional value to verify in output[0] (default 42)\n",
               argv0);
}

ComPtr<IDXGIAdapter1> pickAdapter() {
  ComPtr<IDXGIFactory4> factory;
  HR_THROW(CreateDXGIFactory1(IID_PPV_ARGS(&factory)));

  ComPtr<IDXGIAdapter1> adapter;
  for (UINT i = 0; factory->EnumAdapters1(i, &adapter) != DXGI_ERROR_NOT_FOUND;
       ++i) {
    DXGI_ADAPTER_DESC1 desc{};
    adapter->GetDesc1(&desc);
    if (desc.Flags & DXGI_ADAPTER_FLAG_SOFTWARE)
      continue;
    return adapter;
  }
  throw std::runtime_error("no hardware DXGI adapter found");
}

} // namespace

int main(int argc, char **argv) {
  if (argc < 3) {
    printUsage(argv[0]);
    return 2;
  }

  const char *dxilPath = argv[1];
  const char *entryPoint = argv[2];
  const float expected = (argc >= 4) ? std::stof(argv[3]) : 42.0f;
  const bool enableDebug =
      (argc >= 5) && (std::string(argv[4]) == "--debug");

  if (enableDebug)
    maybeEnableDebugLayer();

  std::vector<uint8_t> dxil;
  try {
    dxil = readFile(dxilPath);
  } catch (const std::exception &ex) {
    std::fprintf(stderr, "%s\n", ex.what());
    return 1;
  }

  if (dxil.size() < 4 || dxil[0] != 'D' || dxil[1] != 'X' || dxil[2] != 'B' ||
      dxil[3] != 'C') {
    std::fprintf(stderr, "expected DXBC/DXIL container, got bad magic\n");
    return 1;
  }

  ComPtr<IDXGIAdapter1> adapter;
  try {
    adapter = pickAdapter();
  } catch (const std::exception &ex) {
    std::fprintf(stderr, "%s\n", ex.what());
    return 1;
  }

  ComPtr<ID3D12Device> device;
  HR(D3D12CreateDevice(adapter.Get(), D3D_FEATURE_LEVEL_11_0,
                       IID_PPV_ARGS(&device)));

  ComPtr<ID3D12CommandQueue> queue;
  D3D12_COMMAND_QUEUE_DESC qDesc{};
  qDesc.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
  HR(device->CreateCommandQueue(&qDesc, IID_PPV_ARGS(&queue)));

  ComPtr<ID3D12CommandAllocator> allocator;
  HR(device->CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_DIRECT,
                                    IID_PPV_ARGS(&allocator)));

  ComPtr<ID3D12GraphicsCommandList> cmdList;
  HR(device->CreateCommandList(0, D3D12_COMMAND_LIST_TYPE_DIRECT, allocator.Get(),
                               nullptr, IID_PPV_ARGS(&cmdList)));

  // Root signature: one SRV table entry at t0, space0 (arg RawBuffer binding).
  D3D12_DESCRIPTOR_RANGE1 srvRange{};
  srvRange.RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_SRV;
  srvRange.NumDescriptors = 1;
  srvRange.BaseShaderRegister = 0;
  srvRange.RegisterSpace = 0;
  srvRange.Flags = D3D12_DESCRIPTOR_RANGE_FLAG_DATA_STATIC;

  D3D12_ROOT_PARAMETER1 rootParam{};
  rootParam.ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
  rootParam.ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL;
  rootParam.DescriptorTable.NumDescriptorRanges = 1;
  rootParam.DescriptorTable.pDescriptorRanges = &srvRange;

  D3D12_VERSIONED_ROOT_SIGNATURE_DESC rsDesc{};
  rsDesc.Version = D3D_ROOT_SIGNATURE_VERSION_1_1;
  rsDesc.Desc_1_1.NumParameters = 1;
  rsDesc.Desc_1_1.pParameters = &rootParam;
  rsDesc.Desc_1_1.Flags = D3D12_ROOT_SIGNATURE_FLAG_NONE;

  ComPtr<ID3DBlob> rsBlob;
  ComPtr<ID3DBlob> rsError;
  HR(D3D12SerializeVersionedRootSignature(&rsDesc, &rsBlob, &rsError));

  ComPtr<ID3D12RootSignature> rootSig;
  if (auto rts0 = extractDxContainerPart(dxil, "RTS0")) {
    std::printf("DXIL contains RTS0 root signature (%zu bytes)\n", rts0->size());
  } else {
    std::printf("DXIL has no RTS0 part\n");
  }
  HR(device->CreateRootSignature(0, rsBlob->GetBufferPointer(),
                                 rsBlob->GetBufferSize(),
                                 IID_PPV_ARGS(&rootSig)));

  D3D12_COMPUTE_PIPELINE_STATE_DESC psoDesc{};
  psoDesc.pRootSignature = rootSig.Get();
  psoDesc.CS = {dxil.data(), dxil.size()};
  psoDesc.NodeMask = 1;

  ComPtr<ID3D12PipelineState> pso;
  const HRESULT psoHr =
      device->CreateComputePipelineState(&psoDesc, IID_PPV_ARGS(&pso));
  if (FAILED(psoHr)) {
    std::fprintf(stderr,
                 "CreateComputePipelineState failed (0x%08lX).\n"
                 "Common causes: root signature mismatch, wrong entry point "
                 "('%s'), or DXIL/runtime incompatibility (LLVM DXIL vs OS "
                 "D3D12).\n",
                 (unsigned long)psoHr, entryPoint);
    (void)enableDebug;
    return 1;
  }

  // Output buffer written via GPU VA packed in the arg buffer.
  ComPtr<ID3D12Resource> outputBuf;
  {
    D3D12_HEAP_PROPERTIES heapProps{};
    heapProps.Type = D3D12_HEAP_TYPE_DEFAULT;
    D3D12_RESOURCE_DESC desc{};
    desc.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
    desc.Width = 256;
    desc.Height = 1;
    desc.DepthOrArraySize = 1;
    desc.MipLevels = 1;
    desc.Format = DXGI_FORMAT_UNKNOWN;
    desc.SampleDesc.Count = 1;
    desc.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
    desc.Flags = D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS;
    HR(device->CreateCommittedResource(
        &heapProps, D3D12_HEAP_FLAG_NONE, &desc, D3D12_RESOURCE_STATE_COMMON,
        nullptr, IID_PPV_ARGS(&outputBuf)));
  }

  const D3D12_GPU_VIRTUAL_ADDRESS outputGpuVa = outputBuf->GetGPUVirtualAddress();
  if (outputGpuVa > 0xFFFFFFFFull) {
    std::fprintf(stderr,
                 "GPU VA does not fit i32 pointer model (0x%llX)\n",
                 (unsigned long long)outputGpuVa);
    return 1;
  }

  ComPtr<ID3D12Resource> argsUpload;
  {
    D3D12_HEAP_PROPERTIES heapProps{};
    heapProps.Type = D3D12_HEAP_TYPE_UPLOAD;
    D3D12_RESOURCE_DESC desc{};
    desc.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
    desc.Width = sizeof(ArgsBlob);
    desc.Height = 1;
    desc.DepthOrArraySize = 1;
    desc.MipLevels = 1;
    desc.Format = DXGI_FORMAT_UNKNOWN;
    desc.SampleDesc.Count = 1;
    desc.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
    HR(device->CreateCommittedResource(
        &heapProps, D3D12_HEAP_FLAG_NONE, &desc,
        D3D12_RESOURCE_STATE_GENERIC_READ, nullptr,
        IID_PPV_ARGS(&argsUpload)));

    ArgsBlob *mapped = nullptr;
    D3D12_RANGE readRange{0, 0};
    HR(argsUpload->Map(0, &readRange, reinterpret_cast<void **>(&mapped)));
    mapped->outputGpuVa = static_cast<UINT32>(outputGpuVa);
    argsUpload->Unmap(0, nullptr);
  }

  ComPtr<ID3D12DescriptorHeap> srvHeap;
  {
    D3D12_DESCRIPTOR_HEAP_DESC heapDesc{};
    heapDesc.NumDescriptors = 1;
    heapDesc.Type = D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV;
    heapDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE;
    HR(device->CreateDescriptorHeap(&heapDesc, IID_PPV_ARGS(&srvHeap)));

    const auto inc =
        device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
    D3D12_CPU_DESCRIPTOR_HANDLE cpu = srvHeap->GetCPUDescriptorHandleForHeapStart();

    D3D12_SHADER_RESOURCE_VIEW_DESC srv{};
    srv.ViewDimension = D3D12_SRV_DIMENSION_BUFFER;
    srv.Shader4ComponentMapping = D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING;
    srv.Format = DXGI_FORMAT_UNKNOWN;
    srv.Buffer.FirstElement = 0;
    srv.Buffer.NumElements = 1;
    srv.Buffer.StructureByteStride = sizeof(ArgsBlob);
    srv.Buffer.Flags = D3D12_BUFFER_SRV_FLAG_NONE;
    device->CreateShaderResourceView(argsUpload.Get(), &srv, cpu);
    (void)inc;
  }

  ComPtr<ID3D12Fence> fence;
  HR(device->CreateFence(0, D3D12_FENCE_FLAG_NONE, IID_PPV_ARGS(&fence)));
  HANDLE fenceEvent = CreateEvent(nullptr, FALSE, FALSE, nullptr);

  // Record dispatch.
  cmdList->SetComputeRootSignature(rootSig.Get());
  ID3D12DescriptorHeap *heaps[] = {srvHeap.Get()};
  cmdList->SetDescriptorHeaps(1, heaps);
  cmdList->SetComputeRootDescriptorTable(
      0, srvHeap->GetGPUDescriptorHandleForHeapStart());
  cmdList->SetPipelineState(pso.Get());
  cmdList->Dispatch(1, 1, 1);
  HR(cmdList->Close());

  ID3D12CommandList *lists[] = {cmdList.Get()};
  queue->ExecuteCommandLists(1, lists);

  HR(queue->Signal(fence.Get(), 1));
  HR(fence->SetEventOnCompletion(1, fenceEvent));
  WaitForSingleObject(fenceEvent, INFINITE);

  // Readback output.
  ComPtr<ID3D12Resource> readback;
  {
    D3D12_HEAP_PROPERTIES heapProps{};
    heapProps.Type = D3D12_HEAP_TYPE_READBACK;
    D3D12_RESOURCE_DESC desc{};
    desc.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
    desc.Width = 256;
    desc.Height = 1;
    desc.DepthOrArraySize = 1;
    desc.MipLevels = 1;
    desc.Format = DXGI_FORMAT_UNKNOWN;
    desc.SampleDesc.Count = 1;
    desc.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
    HR(device->CreateCommittedResource(
        &heapProps, D3D12_HEAP_FLAG_NONE, &desc,
        D3D12_RESOURCE_STATE_COPY_DEST, nullptr, IID_PPV_ARGS(&readback)));
  }

  ComPtr<ID3D12CommandAllocator> copyAlloc;
  HR(device->CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_DIRECT,
                                    IID_PPV_ARGS(&copyAlloc)));
  ComPtr<ID3D12GraphicsCommandList> copyList;
  HR(device->CreateCommandList(0, D3D12_COMMAND_LIST_TYPE_DIRECT, copyAlloc.Get(),
                               nullptr, IID_PPV_ARGS(&copyList)));

  D3D12_RESOURCE_BARRIER barrier{};
  barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
  barrier.Transition.pResource = outputBuf.Get();
  barrier.Transition.StateBefore = D3D12_RESOURCE_STATE_COMMON;
  barrier.Transition.StateAfter = D3D12_RESOURCE_STATE_COPY_SOURCE;
  barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
  copyList->ResourceBarrier(1, &barrier);
  copyList->CopyResource(readback.Get(), outputBuf.Get());
  std::swap(barrier.Transition.StateBefore, barrier.Transition.StateAfter);
  copyList->ResourceBarrier(1, &barrier);
  HR(copyList->Close());

  ID3D12CommandList *copyLists[] = {copyList.Get()};
  queue->ExecuteCommandLists(1, copyLists);
  HR(queue->Signal(fence.Get(), 2));
  HR(fence->SetEventOnCompletion(2, fenceEvent));
  WaitForSingleObject(fenceEvent, INFINITE);

  float result = 0.0f;
  D3D12_RANGE readRange{0, sizeof(float)};
  void *mapped = nullptr;
  HR(readback->Map(0, &readRange, &mapped));
  result = *reinterpret_cast<float *>(mapped);
  readback->Unmap(0, nullptr);

  CloseHandle(fenceEvent);

  std::printf("entry=%s output[0]=%g (expected %g)\n", entryPoint, result,
              expected);

  if (result != expected) {
    std::fprintf(stderr, "VERIFY FAILED\n");
    return 1;
  }

  std::printf("OK\n");
  return 0;
}
