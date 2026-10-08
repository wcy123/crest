module {
}

// -----
module {
  func.func @matmul_2d(%arg0: !hipsr.context, %arg1: tensor<?x4096xf16, #hipsr.mem<device>>, %arg2: tensor<4096x1024xf16, #hipsr.mem<device>>) -> tensor<?x1024xf16, #hipsr.mem<device>> {
    %0 = "hipsr.placeholder"(%arg0, %arg1, %arg2) ({
    ^bb0(%arg3: !shape.shape, %arg4: !shape.shape):
      %c1 = shape.const_size 1
      %c0 = shape.const_size 0
      %2 = shape.get_extent %arg3, %c1 : !shape.shape, !shape.size -> !shape.size
      %3 = shape.get_extent %arg4, %c0 : !shape.shape, !shape.size -> !shape.size
      %4 = shape.from_extents %2 : !shape.size
      %5 = shape.from_extents %3 : !shape.size
      %6 = shape.cstr_eq %4, %5 : !shape.shape, !shape.shape
      %c0_0 = shape.const_size 0
      %c0_1 = shape.const_size 0
      %head, %tail = "shape.split_at"(%arg3, %c0_0) : (!shape.shape, !shape.size) -> (!shape.shape, !shape.shape)
      %head_2, %tail_3 = "shape.split_at"(%arg4, %c0_1) : (!shape.shape, !shape.size) -> (!shape.shape, !shape.shape)
      %7 = shape.cstr_broadcastable %head, %head_2 : !shape.shape, !shape.shape
      %8 = shape.assuming_all %6, %7
      %c0_4 = shape.const_size 0
      %c1_5 = shape.const_size 1
      %9 = shape.get_extent %arg3, %c0_4 : !shape.shape, !shape.size -> !shape.size
      %10 = shape.get_extent %arg4, %c1_5 : !shape.shape, !shape.size -> !shape.size
      %11 = shape.assuming %8 -> (!shape.shape) {
        %12 = shape.broadcast %head, %head_2 : !shape.shape, !shape.shape -> !shape.shape
        %13 = shape.from_extents %9, %10 : !shape.size, !shape.size
        %14 = shape.concat %12, %13 : !shape.shape, !shape.shape -> !shape.shape
        shape.assuming_yield %14 : !shape.shape
      }
      "hipsr.shape_yield"(%11) : (!shape.shape) -> ()
    }) : (!hipsr.context, tensor<?x4096xf16, #hipsr.mem<device>>, tensor<4096x1024xf16, #hipsr.mem<device>>) -> tensor<?x1024xf16, #hipsr.mem<device>>
    %1 = "hipsr.matmul"(%arg0, %arg1, %arg2, %0) : (!hipsr.context, tensor<?x4096xf16, #hipsr.mem<device>>, tensor<4096x1024xf16, #hipsr.mem<device>>, tensor<?x1024xf16, #hipsr.mem<device>>) -> tensor<?x1024xf16, #hipsr.mem<device>>
    return %1 : tensor<?x1024xf16, #hipsr.mem<device>>
  }
}

// -----
module {
  func.func @matmul_1d_rhs(%arg0: !hipsr.context, %arg1: tensor<?x4096xf16, #hipsr.mem<device>>, %arg2: tensor<4096xf16, #hipsr.mem<device>>) -> tensor<?xf16, #hipsr.mem<device>> {
    %0 = "hipsr.placeholder"(%arg0, %arg1, %arg2) ({
    ^bb0(%arg3: !shape.shape, %arg4: !shape.shape):
      %c1 = shape.const_size 1
      %c0 = shape.const_size 0
      %2 = shape.get_extent %arg3, %c1 : !shape.shape, !shape.size -> !shape.size
      %3 = shape.get_extent %arg4, %c0 : !shape.shape, !shape.size -> !shape.size
      %4 = shape.from_extents %2 : !shape.size
      %5 = shape.from_extents %3 : !shape.size
      %6 = shape.cstr_eq %4, %5 : !shape.shape, !shape.shape
      %c0_0 = shape.const_size 0
      %c0_1 = shape.const_size 0
      %head, %tail = "shape.split_at"(%arg3, %c0_0) : (!shape.shape, !shape.size) -> (!shape.shape, !shape.shape)
      %head_2, %tail_3 = "shape.split_at"(%arg4, %c0_1) : (!shape.shape, !shape.size) -> (!shape.shape, !shape.shape)
      %7 = shape.cstr_broadcastable %head, %head_2 : !shape.shape, !shape.shape
      %8 = shape.assuming_all %6, %7
      %c0_4 = shape.const_size 0
      %c0_5 = shape.const_size 0
      %9 = shape.get_extent %arg3, %c0_4 : !shape.shape, !shape.size -> !shape.size
      %10 = shape.get_extent %arg4, %c0_5 : !shape.shape, !shape.size -> !shape.size
      %11 = shape.assuming %8 -> (!shape.shape) {
        %12 = shape.broadcast %head, %head_2 : !shape.shape, !shape.shape -> !shape.shape
        %13 = shape.from_extents %9, %10 : !shape.size, !shape.size
        %14 = shape.concat %12, %13 : !shape.shape, !shape.shape -> !shape.shape
        shape.assuming_yield %14 : !shape.shape
      }
      "hipsr.shape_yield"(%11) : (!shape.shape) -> ()
    }) : (!hipsr.context, tensor<?x4096xf16, #hipsr.mem<device>>, tensor<4096xf16, #hipsr.mem<device>>) -> tensor<?xf16, #hipsr.mem<device>>
    %1 = "hipsr.matmul"(%arg0, %arg1, %arg2, %0) : (!hipsr.context, tensor<?x4096xf16, #hipsr.mem<device>>, tensor<4096xf16, #hipsr.mem<device>>, tensor<?xf16, #hipsr.mem<device>>) -> tensor<?xf16, #hipsr.mem<device>>
    return %1 : tensor<?xf16, #hipsr.mem<device>>
  }
}
