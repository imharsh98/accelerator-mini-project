module PE #(
    parameter DATA_WIDTH = 16,
    parameter SPARSITY_THRESHOLD = 16'h0010  // Configurable sparsity threshold
)(
    input wire clk,
    input wire rst,
    input wire en,
    input wire mode_residual, // 0 = normal, 1 = residual
    input wire signed [DATA_WIDTH-1:0] input_data,
    input wire signed [DATA_WIDTH-1:0] weight_data,
    input wire signed [DATA_WIDTH-1:0] residual_data,
    output reg signed [DATA_WIDTH-1:0] output_data,
    
    // Sparse Detection Unit Outputs
    output wire input_sparse,
    output wire weight_sparse,
    output wire computation_skipped,
    output reg [15:0] sparse_count,
    output reg [15:0] total_count
);

    // Enhanced Sparse Detection Unit
    wire input_is_zero, weight_is_zero;
    wire input_is_sparse, weight_is_sparse;
    wire skip_computation;
    
    // Absolute value computation for threshold comparison
    wire [DATA_WIDTH-1:0] abs_input_data, abs_weight_data;
    assign abs_input_data = (input_data[DATA_WIDTH-1]) ? -input_data : input_data;
    assign abs_weight_data = (weight_data[DATA_WIDTH-1]) ? -weight_data : weight_data;
    
    // Zero detection (exact)
    assign input_is_zero = (input_data == 0);
    assign weight_is_zero = (weight_data == 0);
    
    // Sparsity detection (threshold-based)
    assign input_is_sparse = (abs_input_data < SPARSITY_THRESHOLD) || input_is_zero;
    assign weight_is_sparse = (abs_weight_data < SPARSITY_THRESHOLD) || weight_is_zero;
    
    // Skip computation if either input or weight is sparse
    assign skip_computation = input_is_sparse || weight_is_sparse;
    
    // Output sparse detection signals
    assign input_sparse = input_is_sparse;
    assign weight_sparse = weight_is_sparse;
    assign computation_skipped = skip_computation;
    
    // MAC unit with sparse optimization
    reg signed [2*DATA_WIDTH-1:0] mac_result;
    wire signed [2*DATA_WIDTH-1:0] mult_result;
    
    // Optimized multiplication with early termination
    assign mult_result = skip_computation ? 0 : input_data * weight_data;
    
    // Pattern detection for consecutive sparse operations
    reg [3:0] consecutive_sparse_count;
    reg sparse_pattern_detected;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            consecutive_sparse_count <= 0;
            sparse_pattern_detected <= 0;
        end else if (en) begin
            if (skip_computation) begin
                consecutive_sparse_count <= (consecutive_sparse_count == 4'hF) ? 
                                          4'hF : consecutive_sparse_count + 1;
                sparse_pattern_detected <= (consecutive_sparse_count >= 4);
            end else begin
                consecutive_sparse_count <= 0;
                sparse_pattern_detected <= 0;
            end
        end
    end
    
    // Enhanced MAC with sparse awareness
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mac_result <= 0;
            output_data <= 0;
            sparse_count <= 0;
            total_count <= 0;
        end else if (en) begin
            // Update statistics
            total_count <= total_count + 1;
            if (skip_computation)
                sparse_count <= sparse_count + 1;
            
            // MAC operation with sparse optimization
            if (!skip_computation) begin
                mac_result <= mac_result + mult_result;
            end
            // If sparse, MAC result remains unchanged (implicit accumulation skip)
            
            // Output stage with residual connection support
            if (mode_residual)
                output_data <= mac_result[DATA_WIDTH-1:0] + residual_data;
            else
                output_data <= mac_result[DATA_WIDTH-1:0];
        end
    end
    
    // Power gating signal for downstream units (optional)
    wire power_gate_enable;
    assign power_gate_enable = sparse_pattern_detected;

endmodule

// Enhanced Sparse Detection Unit as a separate module (for reusability)
module sparse_detection_unit #(
    parameter DATA_WIDTH = 16,
    parameter THRESHOLD = 16'h0010
)(
    input wire signed [DATA_WIDTH-1:0] data_in,
    output wire is_sparse,
    output wire is_zero,
    output wire [DATA_WIDTH-1:0] abs_value
);
    
    // Absolute value computation
    assign abs_value = (data_in[DATA_WIDTH-1]) ? -data_in : data_in;
    
    // Detection logic
    assign is_zero = (data_in == 0);
    assign is_sparse = (abs_value < THRESHOLD) || is_zero;
    
endmodule