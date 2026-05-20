`timescale 1ns/1ps

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
    //shift registers
    logic [7:0] tx_reg;
    logic [7:0] rx_reg;

    //bit counter
    logic [2:0] bit_cnt;

    typedef enum logic [2:0] {
        IDLE,
        LOAD_SS,
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
                    next_state  = LOAD_SS;
            end

            LOAD_SS: begin
                next_state  = TRANSFER;
            end

            TRANSFER: begin
                if (bit_cnt == 3'd7)
                    next_state  = WAIT_CLEAR;
            end

            WAIT_CLEAR: begin
                if (cntl == 2'b00)
                    next_state  = IDLE;
            end

            default:;
        endcase
    end

    //bit counter
    always_ff @(posedge ref_clk) begin
        if (!rst_n)
            bit_cnt <= '0;
        else if (state == TRANSFER)
            bit_cnt <= bit_cnt + 1'b1;
        else
            bit_cnt <= '0;
    end

    //ready
    assign ready = (state == IDLE);

    //tx shift register
    always_ff @(posedge ref_clk) begin
        if (!rst_n)
            tx_reg  <= '0;
        else begin
            case (state)
                IDLE: begin
                    if (cntl == 2'b01)
                        tx_reg  <= in;
                end

                TRANSFER: begin
                    tx_reg  <= {tx_reg[6:0], 1'b0};
                end

                default:;
            endcase
        end
    end

    //rx shift register — sample miso on negedge ref_clk (= posedge s_clk)
    always_ff @(negedge ref_clk) begin
        if (!rst_n)
            rx_reg  <= '0;
        else if (state == TRANSFER)
            rx_reg  <= {rx_reg[6:0], miso};
    end

    //slave select logic
    logic [7:0] slave_idx;

    always_ff @(posedge ref_clk) begin
        if (!rst_n)
            slave_idx   <= 8'hFF;
        else if (state == IDLE && cntl == 2'b10)
            slave_idx   <= in;
    end

    logic [7:0] slave_onehot;

    always_comb begin
        //default
        slave_onehot = 8'hFF;

        if (slave_idx < 8'd8)
            slave_onehot    = ~(8'b1 << slave_idx[2:0]);
    end

    //output
    assign mosi     = tx_reg[7];
    assign out      = rx_reg;
    assign ss       = (state == LOAD_SS || state == TRANSFER) ? slave_onehot : 8'hFF;
    assign s_clk    = (state == TRANSFER) ? ~ref_clk : 1'b0;
endmodule
