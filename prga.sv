`timescale 1 ps/ 1 ps

module prga(input logic clk, input logic rst_n,
            input logic en, output logic rdy,
            input logic [23:0] key,
            output logic [7:0] s_addr, input logic [7:0] s_rddata, output logic [7:0] s_wrdata, output logic s_wren,
            output logic [7:0] ct_addr, input logic [7:0] ct_rddata,
            output logic [7:0] pt_addr, input logic [7:0] pt_rddata, output logic [7:0] pt_wrdata, output logic pt_wren);

    // State definitions for the state machine used in this module
    localparam logic [3:0] START =           4'b0000;
    localparam logic [3:0] READ_LENGTH =     4'b0001;
    localparam logic [3:0] WRITE_LENGTH =    4'b0010;
    localparam logic [3:0] READ_I =          4'b0011;
    localparam logic [3:0] READ_J =          4'b0100;
    localparam logic [3:0] WRITE_I =         4'b0101;
    localparam logic [3:0] WRITE_J =         4'b0110;
    localparam logic [3:0] READ_BYTESTREAM = 4'b0111;
    localparam logic [3:0] XOR =             4'b1000;
    localparam logic [3:0] DONE =            4'b1001;

    // Signals for the state machine
    reg [3:0] present_state, next_state;

    // Signals for the counter
    reg [7:0] length, i, j, k, temp_i, temp_j;
    reg [7:0] next_length, next_i, next_j, next_k, next_temp_i, next_temp_j;

    // Advances state + ready/enable protocol
    always_ff @(posedge clk) begin
        if(~rst_n) begin
            rdy <= 1'b1;
            present_state <= DONE;
        end
        else begin
            if(en) begin
                // Initialize Values (counters and state)
                rdy <= 1'b0;
                present_state <= START;
                i <= 8'd1;
                j <= 8'd0;
                k <= 8'd1;
                temp_i <= 8'd1;
                temp_j <= 8'd0;
            end else begin
                // Move each value to the next
                present_state <= next_state;
                i <= next_i;
                j <= next_j;
                k <= next_k;     
                temp_i <= next_temp_i;
                temp_j <= next_temp_j;
                length <= next_length;
                if(present_state == DONE)
                    rdy <= 1'b1;
                else 
                    rdy <= 1'b0;
            end
        end

    end

    // Next state logic for state machine
    always_comb begin

        case(present_state)
            START:           next_state = READ_LENGTH;
            READ_LENGTH:     next_state = WRITE_LENGTH;
            WRITE_LENGTH:    next_state = READ_I;
            READ_I:          next_state = READ_J;
            READ_J:          next_state = WRITE_I;
            WRITE_I:         next_state = WRITE_J;
            WRITE_J:         next_state = READ_BYTESTREAM;
            READ_BYTESTREAM: next_state = XOR;
            XOR:             if(k < length) next_state = READ_I; else next_state = DONE;
            DONE:            next_state = DONE;
            default:         next_state = DONE;
        endcase

    end

    // Output logic for state machine
    always_comb begin

        case(present_state)
            START: 
                begin
                    s_addr = 8'b0;
                    s_wrdata = 8'b0;
                    s_wren = 1'b0;
                    ct_addr = 8'b0;
                    pt_addr = 8'b0;
                    pt_wrdata = 8'b0;
                    pt_wren = 1'b0;

                    next_i = i;
                    next_j = j;
                    next_k = k;
                    next_temp_i = temp_i;
                    next_temp_j = temp_j;
                    next_length = length; 
                end
            READ_LENGTH: 
                begin
                    s_addr = 8'b0;
                    s_wrdata = 8'b0;
                    s_wren = 1'b0;
                    ct_addr = 8'b0;
                    pt_addr = 8'b0;
                    pt_wrdata = 8'b0;
                    pt_wren = 1'b0;

                    next_i = i;
                    next_j = j;
                    next_k = k;
                    next_temp_i = temp_i;
                    next_temp_j = temp_j;
                    next_length = length; 
                end
            WRITE_LENGTH: 
                begin
                    s_addr = 8'b0;
                    s_wrdata = 8'b0;
                    s_wren = 1'b0;
                    ct_addr = 8'b0;
                    pt_addr = 8'b0;
                    pt_wrdata = ct_rddata;
                    pt_wren = 1'b1;

                    next_i = i;
                    next_j = j;
                    next_k = k;
                    next_temp_i = temp_i;
                    next_temp_j = temp_j;
                    next_length = ct_rddata;
                end
            READ_I: 
                begin
                    s_addr = i;
                    s_wrdata = 8'b0;
                    s_wren = 1'b0;
                    ct_addr = 8'b0;
                    pt_addr = 8'b0;
                    pt_wrdata = 8'b0;
                    pt_wren = 1'b0;

                    next_i = i;
                    next_j = j;
                    next_k = k;
                    next_temp_i = temp_i;
                    next_temp_j = temp_j;
                    next_length = length; 
                end
            READ_J: 
                begin
                    s_addr = j + s_rddata; // j = j + s[i]
                    s_wrdata = 8'b0;
                    s_wren = 1'b0;
                    ct_addr = 8'b0;
                    pt_addr = 8'b0;
                    pt_wrdata = 8'b0;
                    pt_wren = 1'b0;

                    next_i = i;
                    next_j = j + s_rddata; // j = j + s[i]
                    next_k = k;
                    next_temp_i = s_rddata; // s[i]
                    next_temp_j = temp_j;
                    next_length = length; 
                end
            WRITE_I: 
                begin
                    s_addr = i; // s[i]
                    s_wrdata = s_rddata; // s[j]
                    s_wren = 1'b1;
                    ct_addr = 8'b0;
                    pt_addr = 8'b0;
                    pt_wrdata = 8'b0;
                    pt_wren = 1'b0;

                    next_i = i;
                    next_j = j;
                    next_k = k;
                    next_temp_i = temp_i;
                    next_temp_j = s_rddata; // s[j]
                    next_length = length; 
                end
            WRITE_J: 
                begin
                    s_addr = j; // s[j]
                    s_wrdata = temp_i; // s[i]
                    s_wren = 1'b1;
                    ct_addr = 8'b0;
                    pt_addr = 8'b0;
                    pt_wrdata = 8'b0;
                    pt_wren = 1'b0;

                    next_i = i;
                    next_j = j;
                    next_k = k;
                    next_temp_i = temp_i;
                    next_temp_j = temp_j;
                    next_length = length; 
                end
            READ_BYTESTREAM: 
                begin
                    s_addr = temp_i + temp_j;
                    s_wrdata = 8'b0;
                    s_wren = 1'b0;
                    ct_addr = k;
                    pt_addr = 8'b0;
                    pt_wrdata = 8'b0;
                    pt_wren = 1'b0;

                    next_i = i;
                    next_j = j;
                    next_k = k;
                    next_temp_i = temp_i;
                    next_temp_j = temp_j;
                    next_length = length; 
                end
            XOR: 
                begin
                    s_addr = 8'b0;
                    s_wrdata = 8'b0;
                    s_wren = 1'b0;
                    ct_addr = 8'b0;
                    pt_addr = k;
                    pt_wrdata = s_rddata ^ ct_rddata;
                    pt_wren = 1'b1;

                    next_i = i + 8'd1;
                    next_j = j;
                    next_k = k + 8'd1;
                    next_temp_i = temp_i;
                    next_temp_j = temp_j;
                    next_length = length; 
                end
            DONE: 
                begin
                    s_addr = 8'b0;
                    s_wrdata = 8'b0;
                    s_wren = 1'b0;
                    ct_addr = 8'b0;
                    pt_addr = 8'b0;
                    pt_wrdata = 8'b0;
                    pt_wren = 1'b0;

                    next_i = i;
                    next_j = j;
                    next_k = k;
                    next_temp_i = temp_i;
                    next_temp_j = temp_j;
                    next_length = length; 
                end
            default: 
                begin
                    s_addr = 8'bx;
                    s_wrdata = 8'bx;
                    s_wren = 1'bx;
                    ct_addr = 8'bx;
                    pt_addr = 8'bx;
                    pt_wrdata = 8'bx;
                    pt_wren = 1'bx;

                    next_i = i;
                    next_j = j;
                    next_k = k;
                    next_temp_i = temp_i;
                    next_temp_j = temp_j;
                    next_length = length; 
                end
        endcase

    end

endmodule: prga
