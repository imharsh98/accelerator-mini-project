`timescale 1ns / 1ps

module PE_Comparison_TB;
    parameter DATA_WIDTH = 16;
    parameter TEST_CYCLES = 100;
    
    // Common signals
    reg clk, rst, en, mode_residual;
    reg signed [DATA_WIDTH-1:0] input_data, weight_data, residual_data;
    
    // Original PE
    wire signed [DATA_WIDTH-1:0] orig_output;
    
    // Enhanced PE
    wire signed [DATA_WIDTH-1:0] enh_output;
    wire computation_skipped;
    wire [15:0] sparse_count, total_count;
    
    // Performance counters
    reg [31:0] orig_cycles, enh_cycles;
    reg [31:0] orig_operations, enh_operations;
    reg [31:0] power_savings;
    
    // Test data arrays
    reg signed [DATA_WIDTH-1:0] test_inputs [0:TEST_CYCLES-1];
    reg signed [DATA_WIDTH-1:0] test_weights [0:TEST_CYCLES-1];
    integer i;
    
    // Clock generation
    always #5 clk = ~clk;
    
    // Original PE instance
    PE #(.DATA_WIDTH(DATA_WIDTH)) orig_pe (
        .clk(clk), .rst(rst), .en(en), .mode_residual(mode_residual),
        .input_data(input_data), .weight_data(weight_data), 
        .residual_data(residual_data), .output_data(orig_output)
    );
    
    // Enhanced PE instance
    PE #(.DATA_WIDTH(DATA_WIDTH), .SPARSITY_THRESHOLD(16'h0010)) enh_pe (
        .clk(clk), .rst(rst), .en(en), .mode_residual(mode_residual),
        .input_data(input_data), .weight_data(weight_data), 
        .residual_data(residual_data), .output_data(enh_output),
        .computation_skipped(computation_skipped),
        .sparse_count(sparse_count), .total_count(total_count)
    );
    
    initial begin
        // Initialize
        clk = 0; rst = 1; en = 0; mode_residual = 0;
        orig_cycles = 0; enh_cycles = 0; orig_operations = 0; enh_operations = 0;
        
        // Generate test data (70% sparse, 30% dense)
        for (i = 0; i < TEST_CYCLES; i = i + 1) begin
            if (i % 10 < 7) begin // 70% sparse
                test_inputs[i] = (i % 3 == 0) ? 0 : $random % 16;
                test_weights[i] = (i % 3 == 1) ? 0 : $random % 16;
            end else begin // 30% dense
                test_inputs[i] = $random % 1000 + 100;
                test_weights[i] = $random % 1000 + 100;
            end
        end
        
        #20 rst = 0; en = 1;
        
        // Run test
        for (i = 0; i < TEST_CYCLES; i = i + 1) begin
            input_data = test_inputs[i];
            weight_data = test_weights[i];
            residual_data = 0;
            
            @(posedge clk);
            
            // Count operations
            orig_operations = orig_operations + 1;
            if (!computation_skipped) enh_operations = enh_operations + 1;
            
            // Verify outputs match
            if (orig_output !== enh_output) begin
                $display("ERROR: Output mismatch at cycle %d: Orig=%d, Enh=%d", 
                        i, orig_output, enh_output);
            end
        end
        
        // Calculate performance metrics
        power_savings = ((orig_operations - enh_operations) * 100) / orig_operations;
        
        // Display results
        $display("\n=== PERFORMANCE COMPARISON ===");
        $display("Test Cycles: %d", TEST_CYCLES);
        $display("Original Operations: %d", orig_operations);
        $display("Enhanced Operations: %d", enh_operations);
        $display("Operations Skipped: %d", orig_operations - enh_operations);
        $display("Power Savings: %d%%", power_savings);
        $display("Sparsity Ratio: %d%%", (sparse_count * 100) / total_count);
        $display("Accuracy: %s", (orig_output == enh_output) ? "PASS" : "FAIL");
        
        if (power_savings > 50) 
            $display("RESULT: Enhanced PE shows significant improvement!");
        else
            $display("RESULT: Minimal improvement - check sparsity levels");
            
        $finish;
    end
    
    // Monitor key signals
    always @(posedge clk) begin
        if (en) begin
            $display("Cycle %d: In=%d, W=%d, Skipped=%b, Out_Orig=%d, Out_Enh=%d", 
                    $time/10, input_data, weight_data, computation_skipped, 
                    orig_output, enh_output);
        end
    end
    
endmodule