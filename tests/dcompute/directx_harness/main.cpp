// Minimal D3D12 compute harness for LDC-generated DXIL kernels.
//
// Current LDC DirectX ABI (targetDirectX): *_kernel writes a float via
// UAV RawBuffer at (u0, space0) using handlefrombinding + getpointer.
//
// Prerequisites for CreateCPS:
//   1. dxv-clean blob (UAV/getpointer + !dx.valver={1,8})
//   2. signed container header hash:  dxv -o=signed.dxil unsigned.dxil
//   3. matching UAV root-sig (do not use LLVM RTS0 — CreateRootSignature rejects it)
//   4. NVIDIA HW needs LLVM DXIL with !llvm.ident + DXC-shaped bitcode (LLVM Target/DirectX).
//      Use --warp only when debugging without the patched LLVM.

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
#include <string>
#include <vector>

using Microsoft::WRL::ComPtr;

#define HR(expr)                                                                 \
  do {                                                                           \
    const HRESULT _hr = (expr);                                                  \
    if (FAILED(_hr)) {                                                           \
      std::fprintf(stderr, "HRESULT 0x%08lX at %s:%d\n", (unsigned long)_hr,     \
                   __FILE__, __LINE__);                                          \
      return 1;                                                                  \
    }                                                                            \
  } while (0)

static std::vector<uint8_t> readFile(const char *path) {
  std::ifstream in(path, std::ios::binary);
  if (!in) {
    std::fprintf(stderr, "failed to open %s\n", path);
    std::exit(2);
  }
  return {(std::istreambuf_iterator<char>(in)), {}};
}

static bool headerHashZero(const std::vector<uint8_t> &dxbc) {
  if (dxbc.size() < 20)
    return true;
  for (int i = 4; i < 20; ++i)
    if (dxbc[i] != 0)
      return false;
  return true;
}

static void printUsage(const char *argv0) {
  std::fprintf(stderr,
               "Usage: %s <kernel.dxil> <entry_point> [expected_float] [--warp]\n"
               "\n"
               "  Sign first: dxv -o=signed.dxil unsigned.dxil\n"
               "  Prefer --warp on NVIDIA until HW CreateCPS accepts LLVM DXIL.\n",
               argv0);
}

int main(int argc, char **argv) {
  if (argc < 3) {
    printUsage(argv[0]);
    return 2;
  }

  const char *dxilPath = argv[1];
  const char *entryPoint = argv[2];
  float expected = 42.0f;
  bool useWarp = false;
  for (int i = 3; i < argc; ++i) {
    if (std::strcmp(argv[i], "--warp") == 0)
      useWarp = true;
    else
      expected = std::stof(argv[i]);
  }

  auto dxil = readFile(dxilPath);
  if (dxil.size() < 4 || std::memcmp(dxil.data(), "DXBC", 4) != 0) {
    std::fprintf(stderr, "expected DXBC container\n");
    return 1;
  }
  if (headerHashZero(dxil)) {
    std::fprintf(stderr,
                 "error: container header hash is zero (unsigned).\n"
                 "  Run: dxv -o=signed.dxil %s\n"
                 "  Then pass signed.dxil to this harness.\n",
                 dxilPath);
    return 1;
  }
  std::printf("loaded %s (%zu bytes) entry=%s warp=%d\n", dxilPath, dxil.size(),
              entryPoint, (int)useWarp);

  HR(CoInitializeEx(nullptr, COINIT_MULTITHREADED));

  ComPtr<IDXGIFactory4> factory;
  HR(CreateDXGIFactory1(IID_PPV_ARGS(&factory)));

  ComPtr<IDXGIAdapter1> adapter;
  if (useWarp) {
    ComPtr<IDXGIAdapter> warp;
    HR(factory->EnumWarpAdapter(IID_PPV_ARGS(&warp)));
    HR(warp.As(&adapter));
    std::printf("using WARP adapter\n");
  } else {
    for (UINT i = 0;
         factory->EnumAdapters1(i, &adapter) != DXGI_ERROR_NOT_FOUND; ++i) {
      DXGI_ADAPTER_DESC1 desc{};
      adapter->GetDesc1(&desc);
      if (!(desc.Flags & DXGI_ADAPTER_FLAG_SOFTWARE))
        break;
      adapter.Reset();
    }
    if (!adapter) {
      std::fprintf(stderr, "no hardware adapter\n");
      return 1;
    }
    std::printf("using hardware adapter\n");
  }

  ComPtr<ID3D12Device> device;
  HR(D3D12CreateDevice(adapter.Get(), D3D_FEATURE_LEVEL_11_0,
                       IID_PPV_ARGS(&device)));

  // Hand-built UAV(u0) table — LLVM RTS0 is rejected by CreateRootSignature.
  D3D12_DESCRIPTOR_RANGE1 range{};
  range.RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_UAV;
  range.NumDescriptors = 1;
  range.BaseShaderRegister = 0;
  range.RegisterSpace = 0;
  range.Flags = D3D12_DESCRIPTOR_RANGE_FLAG_DESCRIPTORS_VOLATILE;

  D3D12_ROOT_PARAMETER1 param{};
  param.ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
  param.ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL;
  param.DescriptorTable.NumDescriptorRanges = 1;
  param.DescriptorTable.pDescriptorRanges = &range;

  D3D12_VERSIONED_ROOT_SIGNATURE_DESC rsDesc{};
  rsDesc.Version = D3D_ROOT_SIGNATURE_VERSION_1_1;
  rsDesc.Desc_1_1.NumParameters = 1;
  rsDesc.Desc_1_1.pParameters = &param;

  ComPtr<ID3DBlob> rsBlob, rsErr;
  HR(D3D12SerializeVersionedRootSignature(&rsDesc, &rsBlob, &rsErr));
  ComPtr<ID3D12RootSignature> rootSig;
  HR(device->CreateRootSignature(0, rsBlob->GetBufferPointer(),
                                 rsBlob->GetBufferSize(),
                                 IID_PPV_ARGS(&rootSig)));
  std::printf("CreateRootSignature(UAV u0) OK\n");

  D3D12_COMPUTE_PIPELINE_STATE_DESC psoDesc{};
  psoDesc.pRootSignature = rootSig.Get();
  psoDesc.CS = {dxil.data(), dxil.size()};
  ComPtr<ID3D12PipelineState> pso;
  const HRESULT psoHr =
      device->CreateComputePipelineState(&psoDesc, IID_PPV_ARGS(&pso));
  if (FAILED(psoHr)) {
    std::fprintf(stderr,
                 "CreateComputePipelineState failed 0x%08lX for '%s'\n"
                 "  If hash was signed and dxv passed: try --warp (HW path may "
                 "crash/reject LLVM DXIL).\n",
                 (unsigned long)psoHr, entryPoint);
    return 1;
  }
  std::printf("CreateComputePipelineState OK\n");

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

  // UAV buffer: one float (plus padding for raw buffer views).
  constexpr UINT64 kBufBytes = 256;
  ComPtr<ID3D12Resource> uavBuf;
  {
    D3D12_HEAP_PROPERTIES hp{D3D12_HEAP_TYPE_DEFAULT};
    D3D12_RESOURCE_DESC rd{};
    rd.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
    rd.Width = kBufBytes;
    rd.Height = 1;
    rd.DepthOrArraySize = 1;
    rd.MipLevels = 1;
    rd.SampleDesc.Count = 1;
    rd.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
    rd.Flags = D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS;
    HR(device->CreateCommittedResource(&hp, D3D12_HEAP_FLAG_NONE, &rd,
                                       D3D12_RESOURCE_STATE_UNORDERED_ACCESS,
                                       nullptr, IID_PPV_ARGS(&uavBuf)));
  }

  ComPtr<ID3D12DescriptorHeap> heap;
  {
    D3D12_DESCRIPTOR_HEAP_DESC hd{};
    hd.NumDescriptors = 1;
    hd.Type = D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV;
    hd.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE;
    HR(device->CreateDescriptorHeap(&hd, IID_PPV_ARGS(&heap)));

    D3D12_UNORDERED_ACCESS_VIEW_DESC uav{};
    uav.Format = DXGI_FORMAT_R32_TYPELESS;
    uav.ViewDimension = D3D12_UAV_DIMENSION_BUFFER;
    uav.Buffer.FirstElement = 0;
    uav.Buffer.NumElements = static_cast<UINT>(kBufBytes / 4);
    uav.Buffer.StructureByteStride = 0;
    uav.Buffer.Flags = D3D12_BUFFER_UAV_FLAG_RAW;
    device->CreateUnorderedAccessView(
        uavBuf.Get(), nullptr, &uav,
        heap->GetCPUDescriptorHandleForHeapStart());
  }

  cmdList->SetPipelineState(pso.Get());
  cmdList->SetComputeRootSignature(rootSig.Get());
  ID3D12DescriptorHeap *heaps[] = {heap.Get()};
  cmdList->SetDescriptorHeaps(1, heaps);
  cmdList->SetComputeRootDescriptorTable(
      0, heap->GetGPUDescriptorHandleForHeapStart());
  cmdList->Dispatch(1, 1, 1);

  D3D12_RESOURCE_BARRIER barrier{};
  barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
  barrier.Transition.pResource = uavBuf.Get();
  barrier.Transition.StateBefore = D3D12_RESOURCE_STATE_UNORDERED_ACCESS;
  barrier.Transition.StateAfter = D3D12_RESOURCE_STATE_COPY_SOURCE;
  barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
  cmdList->ResourceBarrier(1, &barrier);
  HR(cmdList->Close());

  ComPtr<ID3D12Resource> readback;
  {
    D3D12_HEAP_PROPERTIES hp{D3D12_HEAP_TYPE_READBACK};
    D3D12_RESOURCE_DESC rd{};
    rd.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
    rd.Width = kBufBytes;
    rd.Height = 1;
    rd.DepthOrArraySize = 1;
    rd.MipLevels = 1;
    rd.SampleDesc.Count = 1;
    rd.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
    HR(device->CreateCommittedResource(&hp, D3D12_HEAP_FLAG_NONE, &rd,
                                       D3D12_RESOURCE_STATE_COPY_DEST, nullptr,
                                       IID_PPV_ARGS(&readback)));
  }

  ComPtr<ID3D12CommandAllocator> copyAlloc;
  HR(device->CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_DIRECT,
                                    IID_PPV_ARGS(&copyAlloc)));
  ComPtr<ID3D12GraphicsCommandList> copyList;
  HR(device->CreateCommandList(0, D3D12_COMMAND_LIST_TYPE_DIRECT, copyAlloc.Get(),
                               nullptr, IID_PPV_ARGS(&copyList)));
  copyList->CopyResource(readback.Get(), uavBuf.Get());
  HR(copyList->Close());

  ComPtr<ID3D12Fence> fence;
  HR(device->CreateFence(0, D3D12_FENCE_FLAG_NONE, IID_PPV_ARGS(&fence)));
  HANDLE ev = CreateEvent(nullptr, FALSE, FALSE, nullptr);

  ID3D12CommandList *lists1[] = {cmdList.Get()};
  queue->ExecuteCommandLists(1, lists1);
  HR(queue->Signal(fence.Get(), 1));
  HR(fence->SetEventOnCompletion(1, ev));
  WaitForSingleObject(ev, INFINITE);

  ID3D12CommandList *lists2[] = {copyList.Get()};
  queue->ExecuteCommandLists(1, lists2);
  HR(queue->Signal(fence.Get(), 2));
  HR(fence->SetEventOnCompletion(2, ev));
  WaitForSingleObject(ev, INFINITE);

  float result = 0.0f;
  D3D12_RANGE rr{0, sizeof(float)};
  void *mapped = nullptr;
  HR(readback->Map(0, &rr, &mapped));
  result = *reinterpret_cast<float *>(mapped);
  readback->Unmap(0, nullptr);
  CloseHandle(ev);

  std::printf("entry=%s output[0]=%g (expected %g)\n", entryPoint, result,
              expected);
  if (result != expected) {
    std::fprintf(stderr, "VERIFY FAILED\n");
    return 1;
  }
  std::printf("OK\n");
  return 0;
}
