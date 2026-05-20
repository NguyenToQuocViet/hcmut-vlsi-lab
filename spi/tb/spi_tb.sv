`timescale 1ns/1ps

module spi_tb;
    logic       ref_clk;
    logic       rst_n;

    logic       sclk;
    logic       mosi;
    logic       miso;

    logic [7:0] ss;
    logic [7:0] m_in;
    logic [7:0] m_out;
    logic [1:0] cntl;
    logic       m_ready;

    logic       s0_miso;
    logic       s1_miso;
    logic       cs0;
    logic       cs1;
    logic [7:0] s0_in;
    logic [7:0] s1_in;
    logic [7:0] s0_out;
    logic [7:0] s1_out;
    logic       s0_load;
    logic       s1_load;
    logic       s0_ready;
    logic       s1_ready;

    // clock generator
    initial ref_clk = 1'b0;
    always #5 ref_clk = ~ref_clk;

    // DUT
    spi_master spi_master_1 (
        .ref_clk    (ref_clk),
        .rst_n      (rst_n),
        .in         (m_in),
        .out        (m_out),
        .cntl       (cntl),
        .ready      (m_ready),
        .ss         (ss),
        .s_clk      (sclk),
        .miso       (miso),
        .mosi       (mosi)
    );

    spi_slave spi_slave_0 (
        .clk        (ref_clk),
        .rst_n      (rst_n),
        .in         (s0_in),
        .out        (s0_out),
        .load       (s0_load),
        .ready      (s0_ready),
        .cs         (cs0),
        .sclk       (sclk),
        .miso       (s0_miso),
        .mosi       (mosi)
    );

    spi_slave spi_slave_1 (
        .clk        (ref_clk),
        .rst_n      (rst_n),
        .in         (s1_in),
        .out        (s1_out),
        .load       (s1_load),
        .ready      (s1_ready),
        .cs         (cs1),
        .sclk       (sclk),
        .miso       (s1_miso),
        .mosi       (mosi)
    );

    // slave select
    assign cs0  = ss[0];
    assign cs1  = ss[1];

    // miso mux
    assign miso = (!cs0) ? s0_miso : (!cs1) ? s1_miso : 1'b0;

    // ---- HELPER ----
    int pass_cnt;
    int fail_cnt;

    task automatic check(input string name, input logic cond);
        if (cond) begin
            pass_cnt++;
            $display("PASS [%0d]: %s", pass_cnt, name);
        end else begin
            fail_cnt++;
            $display("FAIL [%0d]: %s at %t", fail_cnt, name, $time);
        end
    endtask

    // ---- TEST ----
    initial begin
        // init
        cntl    = 2'b00;
        m_in    = '0;
        s0_in   = '0;
        s1_in   = '0;
        s0_load = 1'b0;
        s1_load = 1'b0;

        // TC1: Reset
        @(posedge ref_clk);
        rst_n = 1'b0;
        @(posedge ref_clk);
        @(posedge ref_clk);
        rst_n = 1'b1;
        @(posedge ref_clk);

        check("master ready after reset", m_ready == 1'b1);
        check("slave0 ready after reset", s0_ready == 1'b1);
        check("slave1 ready after reset", s1_ready == 1'b1);
        check("ss inactive after reset", ss == 8'hFF);
        check("sclk low after reset", sclk == 1'b0);

        // TC2: Master load TX data
        @(posedge ref_clk);
        cntl = 2'b01;
        m_in = 8'hA5;
        @(posedge ref_clk);
        cntl = 2'b00;
        @(posedge ref_clk);
        check("master load tx data", spi_master_1.tx_reg == 8'hA5);

        // TC3: Full duplex transfer master=A5, slave0=3C
        // 1. Slave preload
        s0_in   = 8'h3C;
        s0_load = 1'b1;
        @(posedge ref_clk);
        s0_load = 1'b0;

        // 2. Master load TX
        @(posedge ref_clk);
        cntl = 2'b01;
        m_in = 8'hA5;
        @(posedge ref_clk);
        cntl = 2'b00;

        // 3. Master load slave index
        @(posedge ref_clk);
        cntl = 2'b10;
        m_in = 8'd0;
        @(posedge ref_clk);
        cntl = 2'b00;

        // 4. Start transfer
        @(posedge ref_clk);
        cntl = 2'b11;
        @(posedge ref_clk);
        cntl = 2'b00;

        // wait for ready to deassert then reassert
        wait(m_ready == 1'b0);
        wait(m_ready == 1'b1);
        @(posedge ref_clk);

        $display("m_out=%02h s0_out=%02h", m_out, s0_out);
        check("master rx == slave tx (0x3C)", m_out == 8'h3C);
        check("slave0 rx == master tx (0xA5)", s0_out == 8'hA5);

        // TC4: Transfer to slave 1
        s1_in   = 8'hBB;
        s1_load = 1'b1;
        @(posedge ref_clk);
        s1_load = 1'b0;

        @(posedge ref_clk);
        cntl = 2'b01;
        m_in = 8'h55;
        @(posedge ref_clk);
        cntl = 2'b00;

        @(posedge ref_clk);
        cntl = 2'b10;
        m_in = 8'd1;
        @(posedge ref_clk);
        cntl = 2'b00;

        @(posedge ref_clk);
        cntl = 2'b11;
        @(posedge ref_clk);
        cntl = 2'b00;

        wait(m_ready == 1'b0);
        wait(m_ready == 1'b1);
        @(posedge ref_clk);

        $display("m_out=%02h s1_out=%02h", m_out, s1_out);
        check("master rx == slave1 tx (0xBB)", m_out == 8'hBB);
        check("slave1 rx == master tx (0x55)", s1_out == 8'h55);

        // TC5: Invalid slave index (>=8) -> ss stays FF
        @(posedge ref_clk);
        cntl = 2'b10;
        m_in = 8'd10;
        @(posedge ref_clk);
        cntl = 2'b00;

        @(posedge ref_clk);
        cntl = 2'b01;
        m_in = 8'hFF;
        @(posedge ref_clk);
        cntl = 2'b00;

        @(posedge ref_clk);
        cntl = 2'b11;
        @(posedge ref_clk);
        cntl = 2'b00;

        wait(m_ready == 1'b0);
        check("invalid slave idx -> ss=FF during transfer", ss == 8'hFF);
        wait(m_ready == 1'b1);
        @(posedge ref_clk);

        // TC6: WAIT_CLEAR guard — hold cntl=11
        // reload valid slave
        @(posedge ref_clk);
        cntl = 2'b10;
        m_in = 8'd0;
        @(posedge ref_clk);
        cntl = 2'b00;

        @(posedge ref_clk);
        cntl = 2'b01;
        m_in = 8'hAA;
        @(posedge ref_clk);
        cntl = 2'b00;

        s0_in   = 8'h00;
        s0_load = 1'b1;
        @(posedge ref_clk);
        s0_load = 1'b0;

        @(posedge ref_clk);
        cntl = 2'b11;
        // hold cntl=11 throughout transfer
        wait(m_ready == 1'b0);
        repeat(12) @(posedge ref_clk);
        check("wait_clear: ready stays 0 while cntl=11", m_ready == 1'b0);
        cntl = 2'b00;
        wait(m_ready == 1'b1);
        @(posedge ref_clk);
        check("wait_clear: ready=1 after cntl released", m_ready == 1'b1);

        // TC7: Slave preload blocked when cs=0
        // start a transfer, try to load slave during it
        s0_in   = 8'h11;
        s0_load = 1'b1;
        @(posedge ref_clk);
        s0_load = 1'b0;

        @(posedge ref_clk);
        cntl = 2'b01;
        m_in = 8'h22;
        @(posedge ref_clk);
        cntl = 2'b00;

        @(posedge ref_clk);
        cntl = 2'b11;
        @(posedge ref_clk);
        cntl = 2'b00;

        wait(m_ready == 1'b0);
        // slave is now active (cs=0), try to overwrite tx_load_reg
        @(posedge ref_clk);
        s0_in   = 8'hFF;
        s0_load = 1'b1;
        @(posedge ref_clk);
        s0_load = 1'b0;
        check("slave preload blocked during cs=0", spi_slave_0.tx_load_reg == 8'h11);

        wait(m_ready == 1'b1);
        @(posedge ref_clk);

        // TC8: Loopback — MOSI tied to MISO at master level
        // disconnect slave miso mux, wire mosi directly back
        // We simulate this by loading slave with same data master sends
        // Actually: use a separate approach — select invalid slave so ss=FF,
        // then externally miso = mosi (no slave drives)
        // But our miso mux gives 0 when no slave selected.
        // Alternative: load slave0 with same byte as master
        s0_in   = 8'hC3;
        s0_load = 1'b1;
        @(posedge ref_clk);
        s0_load = 1'b0;

        @(posedge ref_clk);
        cntl = 2'b10;
        m_in = 8'd0;
        @(posedge ref_clk);
        cntl = 2'b00;

        @(posedge ref_clk);
        cntl = 2'b01;
        m_in = 8'hC3;
        @(posedge ref_clk);
        cntl = 2'b00;

        @(posedge ref_clk);
        cntl = 2'b11;
        @(posedge ref_clk);
        cntl = 2'b00;

        wait(m_ready == 1'b0);
        wait(m_ready == 1'b1);
        @(posedge ref_clk);
        check("loopback: master rx == master tx (0xC3)", m_out == 8'hC3);
        check("loopback: slave rx == slave tx (0xC3)", s0_out == 8'hC3);

        // TC9: Back-to-back transactions without extra delay
        s0_in   = 8'hDE;
        s0_load = 1'b1;
        @(posedge ref_clk);
        s0_load = 1'b0;

        @(posedge ref_clk);
        cntl = 2'b01;
        m_in = 8'h77;
        @(posedge ref_clk);
        cntl = 2'b00;

        // first transaction
        @(posedge ref_clk);
        cntl = 2'b11;
        @(posedge ref_clk);
        cntl = 2'b00;

        wait(m_ready == 1'b0);
        wait(m_ready == 1'b1);
        @(posedge ref_clk);

        // immediately reload and start second transaction
        s0_in   = 8'hAB;
        s0_load = 1'b1;
        @(posedge ref_clk);
        s0_load = 1'b0;

        cntl = 2'b01;
        m_in = 8'h99;
        @(posedge ref_clk);
        cntl = 2'b00;

        @(posedge ref_clk);
        cntl = 2'b11;
        @(posedge ref_clk);
        cntl = 2'b00;

        wait(m_ready == 1'b0);
        wait(m_ready == 1'b1);
        @(posedge ref_clk);

        check("back2back tx2: slave rx (0x99)", s0_out == 8'h99);
        check("back2back tx2: master rx (0xAB)", m_out == 8'hAB);

        // Summary
        $display("\nSPI TB DONE: pass=%0d fail=%0d", pass_cnt, fail_cnt);
        if (fail_cnt != 0)
            $fatal(1, "SPI TB FAILED");
        $finish;
    end
endmodule
