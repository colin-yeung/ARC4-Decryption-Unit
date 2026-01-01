module competition(input logic CLOCK_50, input logic [3:0] KEY, output logic [9:0] LEDR,
             output logic [6:0] HEX0, output logic [6:0] HEX1, output logic [6:0] HEX2,
             output logic [6:0] HEX3, output logic [6:0] HEX4, output logic [6:0] HEX5);

    // State definitions for the state machine used in this module
    localparam logic [3:0] IDLE =        4'b0000;
    localparam logic [3:0] START =       4'b0001;
    localparam logic [3:0] PROGRESS =    4'b0010;
    localparam logic [3:0] WAIT_KEY =    4'b0011;
    localparam logic [3:0] WRITE_KEY_1 = 4'b0100;
    localparam logic [3:0] WRITE_KEY_2 = 4'b0101;
    localparam logic [3:0] WRITE_KEY_3 = 4'b0110;
    localparam logic [3:0] DONE =        4'b0111;
    localparam logic [3:0] WAITING =     4'b1000;

    // Signals for the ready-enable protocol and state machine
    logic multicrack_ready, multicrack_enable;
    logic [3:0] present_state, next_state;
    logic [6:0] HEX_KEY0, HEX_KEY1, HEX_KEY2, HEX_KEY3, HEX_KEY4, HEX_KEY5;

    // Signals to connect to the ciphertext
    logic key_valid;
    logic [23:0] key;
    logic [7:0] ct_addr, ct_wrdata, ct_rddata;
    logic ct_wren; 

    // Signals to connect to mbox
    logic [7:0] mbox_addr, mbox_wrdata, mbox_rddata;
    logic mbox_wren;

    logic CLOCK_115, locked, rst_n;

    assign ct_wren = 1'b0;
    assign LEDR = 10'b0;
    
    pll pll_inst (
		.refclk   (CLOCK_50), 
		.rst      (1'b0),
		.outclk_0 (CLOCK_115),
		.locked   (locked)
	);

    mbox MBOX(.address(mbox_addr),
              .clock(CLOCK_115),
              .data(mbox_wrdata),
              .wren(mbox_wren),
              .q(mbox_rddata)
              );

    // This memory holds the data of the cipertext
    ct_mem CT(.address(ct_addr), 
              .clock(CLOCK_115),
              .data(ct_wrdata), 
              .wren(ct_wren), 
              .q(ct_rddata) 
              ); 

    // Instantiate an instance of the multicrack module
    multicrack mc(.clk(CLOCK_115),
                   .rst_n(rst_n),
                   .en(multicrack_enable),
                   .rdy(multicrack_ready),
                   .key_valid(key_valid),
                   .key(key),
                   .ct_addr(ct_addr),
                   .ct_rddata(ct_rddata)
                   );

    // This always blocks handles the ready-enable protocol as well as initializes intial values and advances values to the next ones
    always_ff @(posedge CLOCK_115) begin
        if(!locked)
            present_state <= IDLE;
        else
            present_state <= next_state; 
    end
    
    // This combinational always block controls the next state logic transitions
    always_comb begin

        case(present_state) 
            IDLE: 
                begin 
                    if(mbox_rddata == 8'hff) 
                        next_state = START;
                    else 
                        next_state = IDLE;
                end
            START: 
                begin 
                    if(multicrack_ready)
                        next_state = PROGRESS;
                    else
                        next_state = START; 
                end
            PROGRESS: 
                begin 
                    if(multicrack_ready)
                        next_state = WAIT_KEY;
                    else
                        next_state = PROGRESS; 
                end
            WAIT_KEY:
                begin
                    if(key)
                        next_state = WRITE_KEY_1;
                    else
                        next_state = WAIT_KEY;
                end
            WRITE_KEY_1: 
                begin 
                    next_state = WRITE_KEY_2; 
                end
            WRITE_KEY_2: 
                begin 
                    next_state = WRITE_KEY_3; 
                end
            WRITE_KEY_3: 
                begin 
                    next_state = DONE; 
                end
            DONE: 
                begin 
                    next_state = WAITING; 
                end
            WAITING: 
                begin 
                    if(mbox_rddata == 8'h00)
                        next_state = IDLE;
                    else 
                        next_state = WAITING;
                end
            default: next_state = IDLE;
        endcase

    end 

    // This combinational always blocks controls the outputs of the state machine, including enable, cancel, write enable, and plaintext address signals for each crack module
    always_comb begin

        case(present_state) 
            IDLE: 
            begin
                multicrack_enable = 1'b0;
                mbox_addr = 8'b0; // Continuously read MBOX[0] for 8'hff
                mbox_wrdata = 8'b0;
                mbox_wren = 1'b0;
                rst_n = 1'b1;

                HEX0 = 7'b1111111;
                HEX1 = 7'b1111111;
                HEX2 = 7'b1111111;
                HEX3 = 7'b1111111;
                HEX4 = 7'b1111111;
                HEX5 = 7'b1111111;        
            end 
            START: 
            begin
                multicrack_enable = 1'b1;
                mbox_addr = 8'b1; // This is to clear any 8'hff that could have been written into MBOX[1] in the previous cycle
                mbox_wrdata = 8'b0; 
                mbox_wren = 1'b0;
                rst_n = 1'b0;

                HEX0 = 7'b1111111;
                HEX1 = 7'b1111111;
                HEX2 = 7'b1111111;
                HEX3 = 7'b1111111;
                HEX4 = 7'b1111111;
                HEX5 = 7'b1111111; 
            end
            PROGRESS: 
            begin
                multicrack_enable = 1'b0;
                mbox_addr = 8'd0; 
                mbox_wrdata = 8'b0;
                mbox_wren = 1'b0;
                rst_n = 1'b1;

                HEX0 = 7'b1111111;
                HEX1 = 7'b1111111;
                HEX2 = 7'b1111111;
                HEX3 = 7'b1111111;
                HEX4 = 7'b1111111;
                HEX5 = 7'b1111111; 
            end
            WAIT_KEY: 
            begin
                multicrack_enable = 1'b0;
                mbox_addr = 8'd0; 
                mbox_wrdata = 8'b0;
                mbox_wren = 1'b0;
                rst_n = 1'b1;

                HEX0 = 7'b1111111;
                HEX1 = 7'b1111111;
                HEX2 = 7'b1111111;
                HEX3 = 7'b1111111;
                HEX4 = 7'b1111111;
                HEX5 = 7'b1111111; 
            end
            WRITE_KEY_1: 
            begin
                multicrack_enable = 1'b0;
                mbox_addr = 8'd2; 
                mbox_wrdata = key[23:16];
                mbox_wren = 1'b1;
                rst_n = 1'b1;

                HEX0 = 7'b1111111;
                HEX1 = 7'b1111111;
                HEX2 = 7'b1111111;
                HEX3 = 7'b1111111;
                HEX4 = 7'b1111111;
                HEX5 = 7'b1111111; 
            end
            WRITE_KEY_2: 
            begin
                multicrack_enable = 1'b0;
                mbox_addr = 8'd3; 
                mbox_wrdata = key[15:8];
                mbox_wren = 1'b1;
                rst_n = 1'b1;

                HEX0 = 7'b1111111;
                HEX1 = 7'b1111111;
                HEX2 = 7'b1111111;
                HEX3 = 7'b1111111;
                HEX4 = 7'b1111111;
                HEX5 = 7'b1111111; 
            end
            WRITE_KEY_3: 
            begin
                multicrack_enable = 1'b0;
                mbox_addr = 8'd4; 
                mbox_wrdata = key[7:0];
                mbox_wren = 1'b1;
                rst_n = 1'b1;

                HEX0 = 7'b1111111;
                HEX1 = 7'b1111111;
                HEX2 = 7'b1111111;
                HEX3 = 7'b1111111;
                HEX4 = 7'b1111111;
                HEX5 = 7'b1111111;
            end
            DONE: 
            begin
                multicrack_enable = 1'b0;
                mbox_addr = 8'd1;
                mbox_wrdata = 8'hff;
                mbox_wren = 1'b1;
                rst_n = 1'b1;
                
                HEX0 = 7'b1111111;
                HEX1 = 7'b1111111;
                HEX2 = 7'b1111111;
                HEX3 = 7'b1111111;
                HEX4 = 7'b1111111;
                HEX5 = 7'b1111111; 
            end
            WAITING: 
            begin
                multicrack_enable = 1'b0;
                mbox_addr = 8'b0; // Keep checking MBOX[0] for 8'h00
                mbox_wrdata = 8'b0;
                mbox_wren = 1'b0;
                rst_n = 1'b1; 

                if(key_valid) begin
                    HEX0 = HEX_KEY0;
                    HEX1 = HEX_KEY1;
                    HEX2 = HEX_KEY2;
                    HEX3 = HEX_KEY3;
                    HEX4 = HEX_KEY4;
                    HEX5 = HEX_KEY5;
                end
                else begin
                    HEX0 = 7'b0111111;
                    HEX1 = 7'b0111111;
                    HEX2 = 7'b0111111;
                    HEX3 = 7'b0111111;
                    HEX4 = 7'b0111111;
                    HEX5 = 7'b0111111;
                end
            end 
            default: 
            begin 
                multicrack_enable = 1'b0;
                mbox_addr = 8'b0; 
                mbox_wrdata = 8'b0;
                mbox_wren = 1'b0;
                rst_n = 1'b1; 

                HEX0 = 7'b1111111;
                HEX1 = 7'b1111111;
                HEX2 = 7'b1111111;
                HEX3 = 7'b1111111;
                HEX4 = 7'b1111111;
                HEX5 = 7'b1111111; 
            end
        endcase

    end

    /*------------------------------------------------------------------------------------------------------------------------------------*/

    // This combinational always blocks decoded a key into readable ASCII characters to be displayed on the HEX
    always_comb begin

        // HEX's are ordered gdefcba
        
        case(key[23:20])
            4'b0000: HEX_KEY5 = 7'b1000000;
            4'b0001: HEX_KEY5 = 7'b1111001;
            4'b0010: HEX_KEY5 = 7'b0100100;
            4'b0011: HEX_KEY5 = 7'b0110000;
            4'b0100: HEX_KEY5 = 7'b0011001;
            4'b0101: HEX_KEY5 = 7'b0010010;
            4'b0110: HEX_KEY5 = 7'b0000010;
            4'b0111: HEX_KEY5 = 7'b1111000;
            4'b1000: HEX_KEY5 = 7'b0000000;
            4'b1001: HEX_KEY5 = 7'b0010000;
            4'b1010: HEX_KEY5 = 7'b0001000;
            4'b1011: HEX_KEY5 = 7'b0000011;
            4'b1100: HEX_KEY5 = 7'b1000110;
            4'b1101: HEX_KEY5 = 7'b0100001;
            4'b1110: HEX_KEY5 = 7'b0000110;
            4'b1111: HEX_KEY5 = 7'b0001110;
            default: HEX_KEY5 = 7'b1111111;
        endcase

        case(key[19:16])
            4'b0000: HEX_KEY4 = 7'b1000000;
            4'b0001: HEX_KEY4 = 7'b1111001;
            4'b0010: HEX_KEY4 = 7'b0100100;
            4'b0011: HEX_KEY4 = 7'b0110000;
            4'b0100: HEX_KEY4 = 7'b0011001;
            4'b0101: HEX_KEY4 = 7'b0010010;
            4'b0110: HEX_KEY4 = 7'b0000010;
            4'b0111: HEX_KEY4 = 7'b1111000;
            4'b1000: HEX_KEY4 = 7'b0000000;
            4'b1001: HEX_KEY4 = 7'b0010000;
            4'b1010: HEX_KEY4 = 7'b0001000;
            4'b1011: HEX_KEY4 = 7'b0000011;
            4'b1100: HEX_KEY4 = 7'b1000110;
            4'b1101: HEX_KEY4 = 7'b0100001;
            4'b1110: HEX_KEY4 = 7'b0000110;
            4'b1111: HEX_KEY4 = 7'b0001110;
            default: HEX_KEY4 = 7'b1111111;
        endcase

        case(key[15:12])
            4'b0000: HEX_KEY3 = 7'b1000000;
            4'b0001: HEX_KEY3 = 7'b1111001;
            4'b0010: HEX_KEY3 = 7'b0100100;
            4'b0011: HEX_KEY3 = 7'b0110000;
            4'b0100: HEX_KEY3 = 7'b0011001;
            4'b0101: HEX_KEY3 = 7'b0010010;
            4'b0110: HEX_KEY3 = 7'b0000010;
            4'b0111: HEX_KEY3 = 7'b1111000;
            4'b1000: HEX_KEY3 = 7'b0000000;
            4'b1001: HEX_KEY3 = 7'b0010000;
            4'b1010: HEX_KEY3 = 7'b0001000;
            4'b1011: HEX_KEY3 = 7'b0000011;
            4'b1100: HEX_KEY3 = 7'b1000110;
            4'b1101: HEX_KEY3 = 7'b0100001;
            4'b1110: HEX_KEY3 = 7'b0000110;
            4'b1111: HEX_KEY3 = 7'b0001110;
            default: HEX_KEY3 = 7'b1111111;
        endcase

        case(key[11:8])
            4'b0000: HEX_KEY2 = 7'b1000000;
            4'b0001: HEX_KEY2 = 7'b1111001;
            4'b0010: HEX_KEY2 = 7'b0100100;
            4'b0011: HEX_KEY2 = 7'b0110000;
            4'b0100: HEX_KEY2 = 7'b0011001;
            4'b0101: HEX_KEY2 = 7'b0010010;
            4'b0110: HEX_KEY2 = 7'b0000010;
            4'b0111: HEX_KEY2 = 7'b1111000;
            4'b1000: HEX_KEY2 = 7'b0000000;
            4'b1001: HEX_KEY2 = 7'b0010000;
            4'b1010: HEX_KEY2 = 7'b0001000;
            4'b1011: HEX_KEY2 = 7'b0000011;
            4'b1100: HEX_KEY2 = 7'b1000110;
            4'b1101: HEX_KEY2 = 7'b0100001;
            4'b1110: HEX_KEY2 = 7'b0000110;
            4'b1111: HEX_KEY2 = 7'b0001110;
            default: HEX_KEY2 = 7'b1111111;
        endcase

        case(key[7:4])
            4'b0000: HEX_KEY1 = 7'b1000000;
            4'b0001: HEX_KEY1 = 7'b1111001;
            4'b0010: HEX_KEY1 = 7'b0100100;
            4'b0011: HEX_KEY1 = 7'b0110000;
            4'b0100: HEX_KEY1 = 7'b0011001;
            4'b0101: HEX_KEY1 = 7'b0010010;
            4'b0110: HEX_KEY1 = 7'b0000010;
            4'b0111: HEX_KEY1 = 7'b1111000;
            4'b1000: HEX_KEY1 = 7'b0000000;
            4'b1001: HEX_KEY1 = 7'b0010000;
            4'b1010: HEX_KEY1 = 7'b0001000;
            4'b1011: HEX_KEY1 = 7'b0000011;
            4'b1100: HEX_KEY1 = 7'b1000110;
            4'b1101: HEX_KEY1 = 7'b0100001;
            4'b1110: HEX_KEY1 = 7'b0000110;
            4'b1111: HEX_KEY1 = 7'b0001110;
            default: HEX_KEY1 = 7'b1111111;
        endcase

        case(key[3:0])
            4'b0000: HEX_KEY0 = 7'b1000000;
            4'b0001: HEX_KEY0 = 7'b1111001;
            4'b0010: HEX_KEY0 = 7'b0100100;
            4'b0011: HEX_KEY0 = 7'b0110000;
            4'b0100: HEX_KEY0 = 7'b0011001;
            4'b0101: HEX_KEY0 = 7'b0010010;
            4'b0110: HEX_KEY0 = 7'b0000010;
            4'b0111: HEX_KEY0 = 7'b1111000;
            4'b1000: HEX_KEY0 = 7'b0000000;
            4'b1001: HEX_KEY0 = 7'b0010000;
            4'b1010: HEX_KEY0 = 7'b0001000;
            4'b1011: HEX_KEY0 = 7'b0000011;
            4'b1100: HEX_KEY0 = 7'b1000110;
            4'b1101: HEX_KEY0 = 7'b0100001;
            4'b1110: HEX_KEY0 = 7'b0000110;
            4'b1111: HEX_KEY0 = 7'b0001110;
            default: HEX_KEY0 = 7'b1111111;
        endcase

    end

endmodule: competition
