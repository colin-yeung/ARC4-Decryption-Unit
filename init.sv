module init(input logic clk, input logic rst_n,
            input logic en, output logic rdy,
            output logic [7:0] addr, output logic [7:0] wrdata, output logic wren);

    reg [8:0] increment;

    // This always blocks handles a simple ready-enable protocol, as well as initialize the entire memory space with values of its index
    always @(posedge clk) begin

        if(~rst_n) begin
            rdy = 1'b1;
            increment = 9'd256;
            wren = 1'b0;
        end
        else begin

            if(en) begin
                rdy = 1'b0;
                increment = 8'b0;
            end

            else begin
                wren = 1'b0;
                if(increment <= 8'd255) begin
                    wren = 1'b1;
                    wrdata = increment[7:0];
                    addr = increment[7:0];
                    increment = increment + 9'd1;
                end
                else
                    rdy = 1'b1;
            end
        end
    end

endmodule: init