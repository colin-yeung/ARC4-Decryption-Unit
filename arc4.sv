module arc4(input logic clk, input logic rst_n,
            input logic en, output logic rdy,
            input logic [23:0] key,
            output logic [7:0] ct_addr, input logic [7:0] ct_rddata,
            output logic [7:0] pt_addr, input logic [7:0] pt_rddata, output logic [7:0] pt_wrdata, output logic pt_wren);

    // State definitions for the state machine used in this module
    localparam logic [2:0] IDLE =          3'b000;
    localparam logic [2:0] INIT_PROGRESS = 3'b001;
    localparam logic [2:0] INIT_DONE =     3'b010;
    localparam logic [2:0] KSA_PROGRESS =  3'b011;
    localparam logic [2:0] KSA_DONE =      3'b100;
    localparam logic [2:0] PRGA_PROGRESS = 3'b101;
    localparam logic [2:0] PRGA_DONE =     3'b110;
     
    // Signals for each module - init, ksa, prga 
    logic wren, init_wren, ksa_wren, prga_wren, init_ready, init_enable, ksa_ready, ksa_enable, prga_ready, prga_enable;
    logic [7:0] address, wrdata, init_address, ksa_address, prga_address, init_wrdata, ksa_wrdata, prga_wrdata, read_data;

    // Signals for the state machine
    logic [2:0] present_state, next_state;

    // Signals connected to the s memory are multiplexed based on the state
    assign address = (present_state == INIT_PROGRESS) ? init_address : (present_state == KSA_PROGRESS) ? ksa_address : prga_address; 
    assign wrdata = (present_state == INIT_PROGRESS) ? init_wrdata : (present_state == KSA_PROGRESS) ? ksa_wrdata : prga_wrdata;
    assign wren = (present_state == INIT_PROGRESS) ? init_wren: (present_state == KSA_PROGRESS) ? ksa_wren : prga_wren;

    // S memory contains memory after init, ksa, and prga have been ran
    s_mem s(.address(address),
            .clock(clk),
            .data(wrdata),
            .wren(wren),
            .q(read_data)
            );

    // Runs init 
    init i(.clk(clk),
           .rst_n(rst_n),
           .en(init_enable),
           .rdy(init_ready),
           .addr(init_address),
           .wrdata(init_wrdata),
           .wren(init_wren)
           );

    // Runs ksa
    ksa k(.clk(clk),
          .rst_n(rst_n),
          .en(ksa_enable),
          .rdy(ksa_ready),
          .key(key),
          .addr(ksa_address),
          .rddata(read_data),
          .wrdata(ksa_wrdata),
          .wren(ksa_wren)
          );

    // Runs prga
    prga p(.clk(clk),
           .rst_n(rst_n),
           .en(prga_enable),
           .rdy(prga_ready),
           .key(key),
           .s_addr(prga_address),
           .s_rddata(read_data),
           .s_wrdata(prga_wrdata),
           .s_wren(prga_wren),
           .ct_addr(ct_addr),
           .ct_rddata(ct_rddata),
           .pt_addr(pt_addr),
           .pt_rddata(pt_rddata),
           .pt_wrdata(pt_wrdata),
           .pt_wren(pt_wren)
          );

    // State machine to handle read-enable protocol, as well as init, ksa, and prga once
    always @ (posedge clk) begin
        if(~rst_n) begin
            rdy <= 1'b1;
            present_state <= IDLE;
        end 
        else begin
            if(en) begin
                rdy <= 1'b0;
                present_state <= next_state; 
            end
            else begin
                present_state <= next_state;
                if(present_state == PRGA_DONE)
                    rdy <= 1'b1;
                else 
                    rdy <= 1'b0;
            end
        end 
    end

    // Combinational always block for next state logic 
    always_comb begin
        case(present_state)
            IDLE:
                begin 
                    if(init_ready) 
                        next_state = INIT_PROGRESS; 
                    else 
                        next_state = IDLE; 
                end
            INIT_PROGRESS: 
                begin 
                    if(init_ready) 
                        next_state = INIT_DONE; 
                    else 
                        next_state = INIT_PROGRESS; 
                end
            INIT_DONE: 
                begin
                    if(ksa_ready)
                        next_state = KSA_PROGRESS;
                    else
                        next_state = INIT_DONE;
                end
            KSA_PROGRESS: 
                begin
                    if(ksa_ready) 
                        next_state = KSA_DONE; 
                    else 
                        next_state = KSA_PROGRESS;
                end
            KSA_DONE:
                begin
                    if(prga_ready)
                        next_state = PRGA_PROGRESS;
                    else
                        next_state = KSA_DONE;
                end
            PRGA_PROGRESS:
                begin
                    if(prga_ready)
                        next_state = PRGA_DONE;
                    else
                        next_state = PRGA_PROGRESS;
                end
            PRGA_DONE: next_state = PRGA_DONE;
            default:
                next_state = PRGA_DONE;
        endcase
    end

    // Combinational always block for state machine outputs
    always_comb begin
        case(present_state)
            IDLE: 
                begin
                    init_enable = 1'b1; 
                    ksa_enable = 1'b0;
                    prga_enable = 1'b0;
                end
            INIT_PROGRESS: 
                begin
                    init_enable = 1'b0; 
                    ksa_enable = 1'b0;
                    prga_enable = 1'b0;
                end
            INIT_DONE: 
                begin
                    init_enable = 1'b0; 
                    ksa_enable = 1'b1;
                    prga_enable = 1'b0;
                end
            KSA_PROGRESS: 
                begin
                    init_enable = 1'b0; 
                    ksa_enable = 1'b0;
                    prga_enable = 1'b0;
                end
            KSA_DONE: 
                begin
                    init_enable = 1'b0; 
                    ksa_enable = 1'b0;
                    prga_enable = 1'b1;
                end
            PRGA_PROGRESS:
                begin
                    init_enable = 1'b0; 
                    ksa_enable = 1'b0;
                    prga_enable = 1'b0;
                end
            PRGA_DONE:
                begin
                    init_enable = 1'b0; 
                    ksa_enable = 1'b0;
                    prga_enable = 1'b0;
                end
            default: 
                begin
                    init_enable = 1'b0; 
                    ksa_enable = 1'b0;
                    prga_enable = 1'b0;
                end
        endcase
    end

endmodule: arc4
