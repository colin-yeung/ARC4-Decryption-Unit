`timescale 1 ps/ 1 ps

module ksa(input logic clk, input logic rst_n,
           input logic en, output logic rdy,
           input logic [23:0] key,
           output logic [7:0] addr, input logic [7:0] rddata, output logic [7:0] wrdata, output logic wren);

    // State definitions for the state machine used in this module
    localparam logic [2:0] SET_FORTH =  3'b000;
    localparam logic [2:0] READ_I =     3'b001;
    localparam logic [2:0] READ_J =     3'b010;
    localparam logic [2:0] WRITE_I =    3'b011;
    localparam logic [2:0] WRITE_J =    3'b100;
    localparam logic [2:0] CEASE =      3'b101;

    // Signals for counters and temporary holds for swapping
    logic [7:0] i, j, temp, next_i, next_j, next_temp;

    // Signals for the state machine
    logic [2:0] present_state, next_state;
    
    // Signal and logic to obtain certain bytes since key is in big endian
    logic [7:0] keyindex; 
    // assign keyindex = (i % 3'd3 == 2'd0) ? key[23:16] : 
    //                   (i % 3'd3 == 2'd1) ? key[15:8] : key[7:0];

    // HERE
    logic [1:0] i_mod3, next_i_mod3;
    assign keyindex = (i_mod3 == 2'd0) ? key[23:16] : 
                      (i_mod3 == 2'd1) ? key[15:8] : key[7:0];

    // This sequential block handles the ready-enable protocol as well as signal advancements
    always_ff @(posedge clk) begin
        if(~rst_n) begin
            rdy <= 1'b1;
            present_state = CEASE; 
        end
        else begin

            if(en) begin
                rdy <= 1'b0;
                present_state <= SET_FORTH;
                i <= 8'd0;
                j <= 8'd0;
                temp <= 8'd0;
                i_mod3 <= 2'd0;
            end else begin
                present_state <= next_state;
                i <= next_i;
                j <= next_j;    
                temp <= next_temp;   
                i_mod3 <= next_i_mod3;
                if(present_state == CEASE)
                    rdy <= 1'b1;
                else 
                    rdy <= 1'b0;
            end
        end
    end

    // This combinational always blocks handles next state logic
    always_comb begin 
        case(present_state) 
            SET_FORTH: 
                begin
                    next_state = READ_I;
                end
            READ_I: 
                begin
                    next_state = READ_J; 
                end
            READ_J: 
                begin 
                    next_state = WRITE_I; 
                end 
            WRITE_I: 
                begin
                    next_state = WRITE_J;
                end
            WRITE_J: 
                begin 
                    next_state = (i == 8'd255) ? CEASE : READ_I;
                end
            CEASE: 
                begin
                    next_state = CEASE;
                end
            default: 
                begin
                    next_state = CEASE;
                end
        endcase
    end

    // This combinational always blocks handles state outputs
    always_comb begin
        case(present_state)
            SET_FORTH: 
                begin
                    next_i = 8'd0;
                    next_j = 8'd0;
                    next_temp = 8'd0;
                    next_i_mod3 = 2'd0;

                    addr = 8'b0;
                    wrdata = 8'b0;
                    wren = 1'b0;
                end
            READ_I:
                begin
                    next_i = i;
                    next_j = j;
                    next_temp = 8'd0;
                    next_i_mod3 = i_mod3;

                    addr = i;
                    wrdata = 8'b0;
                    wren = 1'b0;
                end
            READ_J:
                begin
                    next_i = i;
                    next_j = (j + rddata + keyindex); 
                    next_temp = rddata;
                    next_i_mod3 = i_mod3;

                    addr = next_j; 
                    wrdata = 8'b0;
                    wren = 1'b0;
                end
            WRITE_I:
                begin
                    next_i = i;
                    next_j = j;
                    next_temp = temp;
                    next_i_mod3 = i_mod3;

                    addr = i;
                    wrdata = rddata;
                    wren = 1'b1;
                end
            WRITE_J:
                begin
                    next_i = i + 8'd1;
                    next_j = j;
                    next_temp = temp;
                    next_i_mod3 = (i_mod3 == 2'd2) ? 2'd0 : i_mod3 + 2'd1;

                    addr = j;
                    wrdata = temp;
                    wren = 1'b1;
                end
            CEASE: 
                begin
                    next_i = i;
                    next_j = j;
                    next_temp = temp;
                    next_i_mod3 = i_mod3;

                    addr = 8'b0;
                    wrdata = 8'b0;
                    wren = 1'b0;
                end
            default: 
                begin
                    next_i = 8'bx;
                    next_j = 8'bx;
                    next_temp = 8'bx;
                    next_i_mod3 = 2'bx;

                    addr = 8'b0;
                    wrdata = 8'b0;
                    wren = 1'b0;
                end
        endcase 
    end

endmodule: ksa
