#include <metal_stdlib>
using namespace metal;
kernel void kernel_31c22c123214e0bca3334d980349d329(
  device const float* input0 [[buffer(0)]],
  device float* output0 [[buffer(1)]],
  device float* output1 [[buffer(2)]],
  constant uint* uniforms [[buffer(3)]],
  device atomic_uint* status [[buffer(4)]],
  uint i [[thread_position_in_grid]]) {
  if(i>=uniforms[0]) return;
  if(i==0) atomic_fetch_or_explicit(status,0u,memory_order_relaxed);
  float r0=input0[i*1+0];
  if(!isfinite(r0)) atomic_store_explicit(status,1u,memory_order_relaxed);
  float r1=as_type<float>(uniforms[1]);
  if(!isfinite(r1)) atomic_store_explicit(status,1u,memory_order_relaxed);
  float r2=(r0+r1);
  if(!isfinite(r2)) atomic_store_explicit(status,1u,memory_order_relaxed);
  output0[i*1+0]=r2;
  output1[i*2+0]=r0;
  output1[i*2+1]=r2;
}
