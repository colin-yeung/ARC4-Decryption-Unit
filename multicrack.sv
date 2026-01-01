module multicrack(input logic clk, input logic rst_n,
             input logic en, output logic rdy,
             output logic [23:0] key, output logic key_valid,
             output logic [7:0] ct_addr, input logic [7:0] ct_rddata);

	/* ------------------------------------------------------------------------------------------------------------------------------- */	 

    // STATE DEFINITIONS

    localparam logic [2:0] IDLE =  3'b000;
    localparam logic [2:0] CHECK = 3'b001;
    localparam logic [2:0] VALID = 3'b010;
    localparam logic [2:0] WRITE = 3'b011;
    localparam logic [2:0] DONE =  3'b100;

	localparam NUM_CRACKS = 104;

	/* ------------------------------------------------------------------------------------------------------------------------------- */

	// SIGNALS

	logic [NUM_CRACKS - 1:0] crack_enable, crack_ready, crack_key_valid, crack_cancel, crack_standby; // These are all one-hot signals for the 10 crack modules
	logic [7:0] crack_ct_addr [0:NUM_CRACKS - 1]; // Drives the ct_addr output 
	logic [7:0] crack_pt_addr [0:NUM_CRACKS - 1], next_crack_pt_addr [0:NUM_CRACKS - 1]; // Drives pt_addr
	logic [7:0] correct_pt_rddata [0:NUM_CRACKS - 1]; // Holds the correct plaintext read data from each crack module
	logic [23:0] crack_key [0:NUM_CRACKS - 1]; // Individual key for each module, driven to a single key if decoded
	logic sync; // Sync signal waits for all crack modules to be in standby (once non-ASCII read)

	// PT memory signals, multitplexed below
	logic [7:0] pt_addr, pt_wrdata, q; 
	logic pt_wren;

	// State machine signals
	logic [2:0] present_state, next_state;

	/* ------------------------------------------------------------------------------------------------------------------------------- */

	// MULTIPLEXER SIGNAL DRIVERS

	assign sync = &crack_standby; // Sync should be high when all modules assert standby (no key found)
	assign key_valid = |crack_key_valid; // key_valid be high if at least one crack module has found a valid key

	always_comb begin
		ct_addr = '0;
		key = '0;
		pt_wrdata = '0;   
		pt_addr = '0; 
		for (int i = 0; i < NUM_CRACKS; i++) begin
			ct_addr |= crack_ct_addr[i];
			key |= crack_key[i];
			pt_wrdata |= correct_pt_rddata[i];
			pt_addr |= crack_pt_addr[i];
		end
	end

	/* ------------------------------------------------------------------------------------------------------------------------------- */

	// INSTANTIATIONS

	// This memory holds the plaintext if there is a key that is valid and decodes the cipertext
    pt_mem PT(.address(pt_addr - 8'd1), 
              .clock(clk),
              .data(pt_wrdata), // needs decoding for which bits of correct_pt_rddata are written into pt_wrdata
              .wren(pt_wren),   
              .q(q) // should be left unconnected (don't have a signal yet for q)
              ); 

	genvar i;
	generate
		for(i = 0; i < NUM_CRACKS; i++) begin: ct_mem
			crack c(.clk(clk),
					.rst_n(rst_n),
					.en(crack_enable[i]),
					.rdy(crack_ready[i]),
					.cancel(crack_cancel[i]), 
					.sync(sync),
					.standby(crack_standby[i]),
					.start_key(24'(i)),
					.key_increment(24'(NUM_CRACKS)),
					.key(crack_key[i]),
					.key_valid(crack_key_valid[i]),
					.ct_addr(crack_ct_addr[i]),
					.ct_rddata(ct_rddata),
					.correct_pt_addr(crack_pt_addr[i]), 
					.correct_pt_rddata(correct_pt_rddata[i]) // decoded into pt_wrdata
					);
		end
	endgenerate

	/* ------------------------------------------------------------------------------------------------------------------------------- */
    
	// STATE MACHINE FOR READY-ENABLE PROTOCOL

	always @(posedge clk) begin
        if(~rst_n) begin
            rdy <= 1'b1;
            present_state <= IDLE;
        end
        else begin
            if(en) begin
                rdy <= 1'b0;
                present_state <= IDLE;
            end
            else begin
                present_state <= next_state;
                crack_pt_addr <= next_crack_pt_addr;
                if(present_state == DONE)
                    rdy = 1'b1;
                else 
                    rdy = 1'b0;
            end

        end
    end

	always_comb begin
		case(present_state)
			IDLE: 
				begin
					next_state = CHECK;
				end
			CHECK: 
				begin
					if(key_valid)
						next_state = VALID;
					else	
						next_state = CHECK;
				end
			VALID: 
				begin
					next_state = WRITE;
				end
			WRITE: 
				begin
					if(pt_addr == 8'd255)
						next_state = DONE;
					else
						next_state = WRITE;
				end
			DONE: 
				begin
					next_state = DONE; 
				end
			default:
				begin
					next_state = DONE; 
				end
		endcase
	end

	always_comb begin
		case(present_state)
			IDLE: 
				begin
					crack_enable = '1;
					crack_cancel = '0;
					pt_wren = 1'b0;
					next_crack_pt_addr = crack_pt_addr;
				end
			CHECK: 
				begin
					crack_enable = '0;
					crack_cancel = '0;
					pt_wren = 1'b1;
					for(int i = 0; i < NUM_CRACKS; i++) begin
						if(crack_pt_addr[i] != 8'b0) begin  
							next_crack_pt_addr[i] = (crack_pt_addr[i] == 8'd255) ? 8'd1 : crack_pt_addr[i] + 8'd1;
						end
						else begin
							next_crack_pt_addr[i] = 8'd0;  
						end
					end
				end
			VALID: 
				begin
					crack_enable = '0;
					pt_wren = 1'b0;
					crack_cancel = '0;
					next_crack_pt_addr = '{NUM_CRACKS{8'b0}};

					for(int i = 0; i < NUM_CRACKS; i++) begin
						if(crack_key_valid[i]) begin
							crack_cancel = '1;
   							crack_cancel[i] = 1'b0;
							next_crack_pt_addr = crack_pt_addr;
							next_crack_pt_addr[i] = 8'b1;
						end
					end
				end
			WRITE: 
				begin
					crack_enable = '0;
					crack_cancel = '0;
					next_crack_pt_addr = crack_pt_addr;
					pt_wren = 1'b1;

					for(int i = 0; i < NUM_CRACKS; i++) begin
						if(crack_pt_addr[i] != 8'b0) begin  // If this module is active
							next_crack_pt_addr[i] = crack_pt_addr[i] + 8'b1;
						end
					end
				end
			DONE: 
				begin
					crack_enable = '0;
					crack_cancel = '0;
					pt_wren = 1'b0;
					next_crack_pt_addr = crack_pt_addr;
				end
			default:
				begin
					crack_enable = '0;
					crack_cancel = '0;
					pt_wren = 1'b0;
					next_crack_pt_addr = crack_pt_addr;
				end
		endcase
	end

	/* ------------------------------------------------------------------------------------------------------------------------------- */

endmodule: multicrack