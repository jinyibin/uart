module version_reg (clock, reset, data_out);
    input clock;
    input reset;
    output [31:0] data_out;
    reg [31:0] data_out;
    always @ (posedge clock or negedge reset) begin
        if (!reset)
            data_out <= 32'h000000;
        else
            data_out <= 32'hF4C180;
    end
endmodule
