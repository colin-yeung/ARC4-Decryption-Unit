module crack(input logic clk, input logic rst_n,
             input logic en, output logic rdy,
             input logic cancel, input logic sync, output logic standby,
             input logic [23:0] start_key, input logic [23:0] key_increment,
             output logic [23:0] key, output logic key_valid,
             output logic [7:0] ct_addr, input logic [7:0] ct_rddata,
             input [7:0] correct_pt_addr, output [7:0] correct_pt_rddata 
             );

    // State definitions for the state machine used in this module
    localparam logic [2:0] IDLE =          3'b000;
    localparam logic [2:0] CHECK =         3'b001;
    localparam logic [2:0] ARC4_RESET =    3'b010;
    localparam logic [2:0] ARC4_REENABLE = 3'b011;
    localparam logic [2:0] CORRECT_KEY =   3'b100;
    localparam logic [2:0] NO_KEY =        3'b101;
 
    localparam logic [7:0] ASCII_LOW =     8'h20;
    localparam logic [7:0] ASCII_HIGH =    8'h7E;

    // Signals for the ready-enable protocol
    reg arc4_reset, arc4_enable, arc4_ready;

    // Signals for state machine logic
    reg [2:0] present_state, next_state; 

    // Output signals of the state machine
    reg bad_key_reset;
    reg [23:0] temp_key, next_temp_key;
    reg [7:0] arc4_pt_addr, arc4_pt_rddata, arc4_pt_wrdata;
    reg arc4_pt_wren; 
    reg [7:0] pt_addr, pt_rddata;

    // Some signals are multiplexed depending on the state
    assign arc4_reset = bad_key_reset && rst_n; // Either when the rst_n is asserted by user or when bad_key_reset is asserted by state machine
    assign pt_addr = (present_state == CORRECT_KEY) ? correct_pt_addr : arc4_pt_addr; 
    assign correct_pt_rddata = (present_state == CORRECT_KEY) ? pt_rddata : 8'b0;

    // This memory holds the plaintext if there is a key that is valid and decodes the cipertext
    pt_mem PT(.address(pt_addr), 
              .clock(clk),
              .data(arc4_pt_wrdata), 
              .wren(arc4_pt_wren), 
              .q(pt_rddata) 
              );

    // This instantiation of the arc4 module is called multiple times for different keys
    arc4 a4(.clk(clk),
            .rst_n(arc4_reset),
            .en(arc4_enable),
            .rdy(arc4_ready),
            .key(temp_key),
            .ct_addr(ct_addr), 
            .ct_rddata(ct_rddata), 
            .pt_addr(arc4_pt_addr), 
            .pt_rddata(arc4_pt_rddata), 
            .pt_wrdata(arc4_pt_wrdata), 
            .pt_wren(arc4_pt_wren) 
            ); 

    // This sequential always block handles the ready-enable protocol and value updates
    always_ff @(posedge clk) begin

        if(~rst_n) begin
            rdy = 1'b1;
            temp_key <= start_key;
            present_state <= IDLE;
        end
        else begin
            if(en) begin
                rdy <= 1'b0;
                present_state <= next_state;
            end 
            else begin
                if(cancel) begin
                    rdy <= 1'b1;
                    present_state <= NO_KEY;
                end
                else begin
                    present_state <= next_state;
                    temp_key <= next_temp_key;
                    if(present_state == CORRECT_KEY || present_state == NO_KEY)
                        rdy <= 1'b1;
                    else
                        rdy <= 1'b0;
                end
                
            end
        end

    end

    // This combinational always block handles the next state updates
    always_comb begin
        case(present_state) 
            IDLE:
                begin
                    next_state = CHECK; 
                end
            CHECK: 
                begin
                    if(arc4_pt_wren) begin
                        if((arc4_pt_wrdata < ASCII_LOW || arc4_pt_wrdata > ASCII_HIGH) && pt_addr > 8'b0)
                            next_state = ARC4_RESET;
                        else if((arc4_pt_wrdata < ASCII_LOW || arc4_pt_wrdata > ASCII_HIGH) && temp_key == 24'hffffff) 
                            next_state = NO_KEY;
                        else
                            next_state = CHECK;
                    end
                    else if(arc4_ready)
                        next_state = CORRECT_KEY;
                    else 
                        next_state = CHECK;
                end
            ARC4_RESET:
                begin
                    if(sync) // The top-level module asserts a 'sync' signal when all crack modules have not found a key and is ready to increment again
                        next_state = ARC4_REENABLE;
                    else
                        next_state = ARC4_RESET;
                end
            ARC4_REENABLE:
                begin
                    next_state = CHECK; 
                end
            CORRECT_KEY:
                begin
                    next_state = CORRECT_KEY;
                end
            NO_KEY:
                begin
                    next_state = NO_KEY;
                end
            default: 
                begin
                    next_state = NO_KEY;
                end
        endcase
    end

    // This combinational block handles the outputs of the state machine
    always_comb begin
        case(present_state)
            IDLE:
                begin
                    next_temp_key = start_key;
                    arc4_enable = 1'b1;
                    bad_key_reset = 1'b1;
                    key_valid = 1'b0;
                    key = 24'b0;
                    standby = 1'b0;
                end
            CHECK:
                begin
                    next_temp_key = temp_key;
                    arc4_enable = 1'b0;
                    bad_key_reset = 1'b1;
                    key_valid = 1'b0;
                    key = 24'b0;
                    standby = 1'b0;
                end
            ARC4_RESET:
                begin
                    next_temp_key = temp_key;
                    arc4_enable = 1'b0;
                    bad_key_reset = 1'b0;
                    key_valid = 1'b0;
                    key = 24'b0;
                    standby = 1'b1;
                end
            ARC4_REENABLE:
                begin
                    next_temp_key = temp_key + key_increment;
                    arc4_enable = 1'b1;
                    bad_key_reset = 1'b1;
                    key_valid = 1'b0;
                    key = 24'b0;
                    standby = 1'b0;
                end
            CORRECT_KEY:
                begin
                    next_temp_key = temp_key;
                    arc4_enable = 1'b0;
                    bad_key_reset = 1'b1;
                    key_valid = 1'b1;
                    key = temp_key;
                    standby = 1'b0;
                end
            NO_KEY:
                begin
                    next_temp_key = temp_key;
                    arc4_enable = 1'b0;
                    bad_key_reset = 1'b1;
                    key_valid = 1'b0;
                    key = 24'b0;
                    standby = 1'b0;
                end
            default:
                begin
                    next_temp_key = 24'bx;
                    arc4_enable = 1'bx;
                    bad_key_reset = 1'bx;
                    key = 24'bx;
                    standby = 1'bx;
                end
        endcase
    end
    
endmodule: crack

