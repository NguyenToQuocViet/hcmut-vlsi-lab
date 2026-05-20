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
    logic [7:0] rx_next;

    assign rx_next = {rx_reg[6:0], mosi};

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            tx_load_reg <= '0;
        else if (cs && load)
            tx_load_reg <= in;
    end

    always_ff @(posedge sclk or negedge rst_n) begin
        if (!rst_n)
            rx_reg <= '0;
        else if (!cs)
            rx_reg <= rx_next;
    end

    always_ff @(negedge sclk or posedge cs or negedge rst_n) begin
        if (!rst_n)
            tx_shift_reg <= '0;
        else if (cs)
            tx_shift_reg <= tx_load_reg;
        else
            tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
    end

    assign ready = cs;
    assign miso  = tx_shift_reg[7];
    assign out   = (!cs) ? rx_next : rx_reg;
endmodule
