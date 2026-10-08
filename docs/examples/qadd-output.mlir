module {
  func.func @qadd(%arg0: !hip.context, %arg1: tensor<1x128x32xi8>, %arg2: tensor<1x128x32xi8>) -> tensor<1x128x32xi8> {
    %0 = "hip.constant"() {value = dense<2.500000e-01> : tensor<f32>} : () -> tensor<f32>
    %1 = "hip.constant"() {value = dense<-5> : tensor<i8>} : () -> tensor<i8>
    %2 = "hip.constant"() {value = dense<5.000000e-01> : tensor<f32>} : () -> tensor<f32>
    %3 = "hip.constant"() {value = dense<3> : tensor<i8>} : () -> tensor<i8>
    %4 = "hip.constant"() {value = dense<1.250000e-01> : tensor<f32>} : () -> tensor<f32>
    %5 = "hip.constant"() {value = dense<7> : tensor<i8>} : () -> tensor<i8>
    %6 = tensor.empty() : tensor<1x128x32xf32>
    %7 = "hip.dequantize_linear"(%arg0, %arg1, %0, %1, %6) {axis = 1 : i64, block_size = 0 : i64} : (!hip.context, tensor<1x128x32xi8>, tensor<f32>, tensor<i8>, tensor<1x128x32xf32>) -> tensor<1x128x32xf32>
    %8 = tensor.empty() : tensor<1x128x32xf32>
    %9 = "hip.dequantize_linear"(%arg0, %arg2, %2, %3, %8) {axis = 1 : i64, block_size = 0 : i64} : (!hip.context, tensor<1x128x32xi8>, tensor<f32>, tensor<i8>, tensor<1x128x32xf32>) -> tensor<1x128x32xf32>
    %10 = tensor.empty() : tensor<1x128x32xf32>
    %11 = "hip.add"(%arg0, %7, %9, %10) : (!hip.context, tensor<1x128x32xf32>, tensor<1x128x32xf32>, tensor<1x128x32xf32>) -> tensor<1x128x32xf32>
    %12 = tensor.empty() : tensor<1x128x32xi8>
    %13 = "hip.qadd"(%arg0, %arg1, %arg2, %12) {lhs_scale = 2.500000e-01 : f32, lhs_zp = -5 : i64, output_scale = 1.250000e-01 : f32, output_zp = 7 : i64, rhs_scale = 5.000000e-01 : f32, rhs_zp = 3 : i64} : (!hip.context, tensor<1x128x32xi8>, tensor<1x128x32xi8>, tensor<1x128x32xi8>) -> tensor<1x128x32xi8>
    return %13 : tensor<1x128x32xi8>
  }
}
