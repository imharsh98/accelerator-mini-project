module PE #(
    parameter DATA_WIDTH = 16
)(
    input wire clk,
    input wire rst,
    input wire en,
    input wire mode_residual, // 0 = normal, 1 = residual
    input wire signed [DATA_WIDTH-1:0] input_data,
    input wire signed [DATA_WIDTH-1:0] weight_data,
    input wire signed [DATA_WIDTH-1:0] residual_data,
    output reg signed [DATA_WIDTH-1:0] output_data
);

    reg signed [2*DATA_WIDTH-1:0] mac_result;
    wire signed [2*DATA_WIDTH-1:0] mult_result;

    assign mult_result = (input_data == 0) ? 0 : input_data * weight_data;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mac_result <= 0;
            output_data <= 0;
        end else if (en) begin
            mac_result <= mac_result + mult_result;

            if (mode_residual)
                output_data <= mac_result[DATA_WIDTH-1:0] + residual_data;
            else
                output_data <= mac_result[DATA_WIDTH-1:0];
        end
    end

endmodule
