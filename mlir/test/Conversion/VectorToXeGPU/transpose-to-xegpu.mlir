// RUN: mlir-opt %s -convert-vector-to-xegpu -split-input-file | FileCheck %s

// -----
gpu.module @xevm_module {
gpu.func @transpose_1x1024x24x64(
    %arg0: memref<1x1024x24x64xf16>,
    %arg1: memref<1x24x1024x64xf16>) kernel
    attributes {known_block_size = array<i32: 256, 1, 1>} {
  %pad = ub.poison : f16
  %c0 = arith.constant 0 : index
  %block_id_x = gpu.block_id x
  %block_id_y = gpu.block_id y
  %block_id_z = gpu.block_id z
  %seq_off = affine.apply affine_map<()[s0] -> (s0 * 16)>()[%block_id_y]
  %hid_off = affine.apply affine_map<()[s0] -> (s0 * 8)>()[%block_id_z]
  %vec = vector.transfer_read %arg0[%c0, %seq_off, %block_id_x, %hid_off], %pad
    {in_bounds = [true, true, true, true]}
    : memref<1x1024x24x64xf16>, vector<1x16x1x8xf16>
  %transposed = vector.transpose %vec, [0, 2, 1, 3]
    : vector<1x16x1x8xf16> to vector<1x1x16x8xf16>
  vector.transfer_write %transposed, %arg1[%c0, %block_id_x, %seq_off, %hid_off]
    {in_bounds = [true, true, true, true]}
    : vector<1x1x16x8xf16>, memref<1x24x1024x64xf16>
  gpu.return
}

// CHECK-LABEL: @transpose_1x1024x24x64
// CHECK-DAG: %[[C1536:.+]] = arith.constant 1536 : index
// CHECK-DAG: %[[C64:.+]] = arith.constant 64 : index
// CHECK-DAG: %[[C65536:.+]] = arith.constant 65536 : index

// Read from memref<1x1024x24x64xf16>, strides [1572864, 1536, 64, 1].
// Scalar base offset: seq_off * 1536 (original dim1 stride),
//                    block_id_x * 64  (original dim2 stride).
// CHECK:     arith.muli %{{.+}}, %[[C1536]] : index
// CHECK:     arith.muli %block_id_x, %[[C64]] : index
// CHECK:     xegpu.load {{.*}} -> vector<1x1x16x8xf16>

// Write to memref<1x24x1024x64xf16>, strides [1572864, 65536, 64, 1].
// Scalar base offset: block_id_x * 65536 (original dim1 stride),
//                    seq_off * 64        (original dim2 stride).
// CHECK:     arith.muli %block_id_x, %[[C65536]] : index
// CHECK:     arith.muli %{{.+}}, %[[C64]] : index
// CHECK:     xegpu.store {{.*}}

}
