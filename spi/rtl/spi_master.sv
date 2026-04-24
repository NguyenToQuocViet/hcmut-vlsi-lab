module spi_master
(   
    //system interface
    input logic         ref_clk,
    input logic         rst_n,

    input logic [7:0]   in,
    output logic [7:0]  out,

    input logic [1:0]   cntl,
    output logic        ready,
    
    //slave interface
    output logic        s_clk,

    output logic        mosi,
    input logic         miso,
 
    output logic [7:0]  ss
);
    //shift register
    logic [7:0] tx_reg;

    //timer
    logic       trans_start;
    logic [2:0] timer;

    always_ff @(posedge ref_clk) begin
        if (!rst_n) begin
            timer   <= '0;
        end else if (trans_start) begin
            timer   <= timer + 1'b1;
        end else begin  //reset khi khong transfer
            timer   <= '0;
        end
    end
    
    typedef enum logic [1:0] {
        IDLE,
        TRANSFER,
        WAIT_CLEAR
    } state_t;

    state_t state, next_state;
    
    //state update
    always_ff @(posedge ref_clk) begin
        if (!rst_n)
            state   <= IDLE;
        else
            state   <= next_state;
    end

    //next state fsm
    always_comb begin
        //default
        next_state  = state;

        case (state)
            IDLE: begin
                if (cntl == 2'b11)
                    next_state  = TRANSFER;
            end

            TRANSFER: begin
                if (timer == 3'b111)
                    next_state  = WAIT_CLEAR;
            end
            
            //state nay de guard resend do system khong chuyen ctnl ve 0
            WAIT_CLEAR: begin
                if (cntl == 2'b00)
                    next_state  = IDLE;
            end

            default:;
        endcase
    end

    //output fsm
    always_comb begin
        //default   
        trans_start = 1'b0;
        ready       = 1'b1;

        case (state)
            IDLE: begin
                //ready       = 1'b1;
            end

            TRANSFER: begin
                trans_start  = 1'b1;
                ready        = 1'b0;
            end

            WAIT_CLEAR: begin
                //trans_start = 1'b0;
                ready       = 1'b0;
            end

            default:;
        endcase
    end

    //load logic
    always_ff @(posedge ref_clk) begin
        /*if (state == IDLE) begin
            if (cntl == 2'b01)
                tx_reg  <= in;
        end else if (state == TRANSFER) begin
            tx_reg  <= {tx_reg[6:0], miso};
        end*/

        case (state)
            IDLE: begin
                if (cntl == 2'b01)
                    tx_reg  <= in;
            end

            TRANSFER: begin
                tx_reg  <= {tx_reg[6:0], miso};
            end

            default:;
        endcase
    end     
    
    //slave select logic
    logic [7:0] slave_idx;

    always_ff @(posedge ref_clk) begin
        if (!rst_n) begin
            slave_idx   <= 8'hFF;
        end else if (state == IDLE && cntl == 2'b10)
            slave_idx   <= in;
    end
    
    logic [7:0] slave_onehot;

    always_comb begin
        //default
        slave_onehot = 8'hFF;

        if (slave_idx < 8'd8)
            slave_onehot    = ~(8'b1 << slave_idx[2:0]);
    end

    assign ss   = (state == TRANSFER) ? slave_onehot : 8'hFF;
    
    /*
    //transfer logic
    always_ff @(posedge ref_clk) begin
        if (state == TRANSFER) begin
            //mosi        <= tx_reg[7];
            tx_reg      <= {tx_reg[6:0], miso};
        end
    end*/

    //output
    assign mosi     = tx_reg[7];
    assign out      = tx_reg;
    assign s_clk    = (state == TRANSFER) ? ref_clk : 1'b0; //gate s_clk
endmodule
