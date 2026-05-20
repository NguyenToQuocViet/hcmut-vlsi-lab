`timescale 1ns/1ps

module spi_slave
(
    //master interface
    input logic         sclk,
    input logic         mosi,
    output logic        miso,

    input logic         cs,

    //system interface
    input logic         clk,
    input logic         rst_n,

    input logic [7:0]   in,
    output logic [7:0]  out,

    input logic         load,
    output logic        ready
);
    logic [7:0] tx_load_reg;
    logic [7:0] tx_shift_reg;
    logic [7:0] rx_reg;
    logic       first_bit;

    //system domain: latch TX data when idle
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            tx_load_reg <= '0;
        else if (cs && load)
            tx_load_reg <= in;
    end

    //tx shift — negedge sclk
    always_ff @(negedge sclk or posedge cs or negedge rst_n) begin
        if (!rst_n) begin
            tx_shift_reg    <= '0;
            first_bit       <= 1'b1;
        end else if (cs) begin
            tx_shift_reg    <= tx_load_reg;
            first_bit       <= 1'b1;
        end else begin
            if (first_bit) begin
                tx_shift_reg    <= {tx_load_reg[6:0], 1'b0};
                first_bit       <= 1'b0;
            end else begin
                tx_shift_reg    <= {tx_shift_reg[6:0], 1'b0};
            end
        end
    end

    //rx shift — posedge sclk
    always_ff @(posedge sclk or negedge rst_n) begin
        if (!rst_n)
            rx_reg  <= '0;
        else if (!cs)
            rx_reg  <= {rx_reg[6:0], mosi};
    end

    //output
    assign miso     = cs ? 1'b0 : (first_bit ? tx_load_reg[7] : tx_shift_reg[7]);
    assign ready    = cs;
    assign out      = rx_reg;
endmodule
