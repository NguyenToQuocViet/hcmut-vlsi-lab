`timescale 1ns/1ps

module ring_flasher_tb;
    import ring_flasher_pkg::*;

    // ── DUT interface ────────────────────────────────────────────
    logic clk, rst_n, rep;
    logic [NUM_LEDS-1:0] leds;

    ring_flasher dut (.clk, .rst_n, .rep, .leds);

    // 5 MHz → 200 ns period
    initial clk = 0;
    always #100 clk = ~clk;

    // ── Helpers ──────────────────────────────────────────────────
    int pass_cnt = 0, fail_cnt = 0;

    task automatic chk(input string msg, input logic cond);
        if (cond) begin
            $display("[PASS] %s", msg);
            pass_cnt++;
        end else begin
            $display("[FAIL] %s  (time=%0t)", msg, $time);
            fail_cnt++;
        end
    endtask

    // Chờ n tick thực sự từ counter (robust hơn đếm clock)
    task automatic wait_ticks(input int n);
        repeat(n) @(posedge clk iff dut.tick);
        #1; // cho non-blocking assignments settle
    endtask

    task automatic do_reset();
        rst_n = 0; rep = 0;
        repeat(4) @(posedge clk);
        @(negedge clk); rst_n = 1;
        #1;
    endtask

    function automatic logic all_zero();
        for (int i = 0; i < NUM_LEDS; i++)
            if (dut.led_brightness[i] != 0) return 0;
        return 1;
    endfunction

    // ── Test cases ───────────────────────────────────────────────
    initial begin
        $dumpfile("ring_flasher_tb.vcd");
        $dumpvars(0, ring_flasher_tb);

        // ── TC1: Reset ──────────────────────────────────────────
        $display("\n── TC1: Reset ──");
        do_reset();
        chk("TC1.1 state=IDLE",       dut.state   == IDLE);
        chk("TC1.2 pos_ptr=15",       dut.pos_ptr == NUM_LEDS - 1);
        chk("TC1.3 leds=0",           leds        == '0);
        chk("TC1.4 all brightness=0", all_zero());

        // ── TC2: IDLE hold (rep=0) ──────────────────────────────
        $display("\n── TC2: IDLE hold (rep=0) ──");
        wait_ticks(3);
        chk("TC2.1 still IDLE",     dut.state == IDLE);
        chk("TC2.2 leds still off", leds      == '0);

        // ── TC3: IDLE → FORWARD ─────────────────────────────────
        $display("\n── TC3: IDLE → FORWARD ──");
        @(negedge clk); rep = 1;
        @(posedge clk); #1;
        chk("TC3.1 state=FORWARD", dut.state == FORWARD);

        // ── TC4: FORWARD step 1 — led[0] sáng ──────────────────
        $display("\n── TC4: FORWARD step 1 ──");
        wait_ticks(1);
        chk("TC4.1 pos_ptr=0",              dut.pos_ptr           == 0);
        chk("TC4.2 led[0] brightness=max",  dut.led_brightness[0] == BRIGHTNESS_LEVELS);
        chk("TC4.3 led[1] brightness=0",    dut.led_brightness[1] == 0);

        // ── TC5: FORWARD step 2 — led[1] sáng, led[0] decay ────
        $display("\n── TC5: FORWARD step 2 ──");
        wait_ticks(1);
        chk("TC5.1 pos_ptr=1",              dut.pos_ptr           == 1);
        chk("TC5.2 led[1] brightness=max",  dut.led_brightness[1] == BRIGHTNESS_LEVELS);
        chk("TC5.3 led[0] decayed to 4",    dut.led_brightness[0] == BRIGHTNESS_LEVELS - 1);

        // ── TC6: FORWARD → BACKWARD sau đúng 12 step ───────────
        $display("\n── TC6: FORWARD → BACKWARD ──");
        wait_ticks(CW_STEPS - 2); // 2 tick đã đi rồi
        chk("TC6.1 state=BACKWARD",         dut.state                     == BACKWARD);
        chk("TC6.2 pos_ptr=11",             dut.pos_ptr                   == CW_STEPS - 1);
        chk("TC6.3 led[11] brightness=max", dut.led_brightness[CW_STEPS-1] == BRIGHTNESS_LEVELS);

        // ── TC7: BACKWARD step 1 ────────────────────────────────
        $display("\n── TC7: BACKWARD step 1 ──");
        wait_ticks(1);
        chk("TC7.1 pos_ptr=10",             dut.pos_ptr            == CW_STEPS - 2);
        chk("TC7.2 led[10] brightness=max", dut.led_brightness[10] == BRIGHTNESS_LEVELS);
        chk("TC7.3 led[11] decayed to 4",   dut.led_brightness[11] == BRIGHTNESS_LEVELS - 1);

        // ── TC8: BACKWARD → FORWARD (rep=1, loop) ───────────────
        $display("\n── TC8: BACKWARD → FORWARD loop (rep=1) ──");
        // rep=1 đã set, 1 BACKWARD tick xong, cần ACW_STEPS-1=7 tick nữa
        wait_ticks(ACW_STEPS - 1);
        chk("TC8.1 state=FORWARD", dut.state    == FORWARD);
        chk("TC8.2 step_cnt=0",    dut.step_cnt == 0);

        // ── TC9: BACKWARD → DECAY (rep=0) ───────────────────────
        $display("\n── TC9: BACKWARD → DECAY (rep=0) ──");
        wait_ticks(CW_STEPS);               // hoàn thành FORWARD thứ 2
        chk("TC9.0 entered BACKWARD", dut.state == BACKWARD);
        @(negedge clk); rep = 0;
        wait_ticks(ACW_STEPS);              // BACKWARD với rep=0
        chk("TC9.1 state=DECAY",      dut.state == DECAY);

        // ── TC10: DECAY → IDLE ──────────────────────────────────
        // max brightness vào DECAY = BRIGHTNESS_LEVELS = 5
        // cần 5 tick để về 0, tick thứ 6 để FSM register IDLE
        $display("\n── TC10: DECAY → IDLE ──");
        wait_ticks(BRIGHTNESS_LEVELS + 1);
        chk("TC10.1 state=IDLE",       dut.state == IDLE);
        chk("TC10.2 all brightness=0", all_zero());
        chk("TC10.3 leds all off",     leds      == '0);

        // ── TC11: PWM — brightness=5 → luôn on ─────────────────
        $display("\n── TC11: PWM max brightness ──");
        // Từ IDLE: start, chờ 1 step → led[0].brightness=5
        @(negedge clk); rep = 1;
        @(posedge clk); #1;
        wait_ticks(1);
        chk("TC11.0 led[0].brightness=5", dut.led_brightness[0] == BRIGHTNESS_LEVELS);
        begin
            int on_cnt = 0;
            repeat(BRIGHTNESS_LEVELS) begin
                @(posedge clk); #1;
                if (leds[0]) on_cnt++;
            end
            // brightness=5: 5>0,5>1,5>2,5>3,5>4 → all true → on 5/5
            chk("TC11.1 led[0] on 5/5 PWM cycles", on_cnt == BRIGHTNESS_LEVELS);
        end

        // ── TC12: PWM — brightness=0 → luôn off ─────────────────
        $display("\n── TC12: PWM zero brightness ──");
        // led[15] chưa bao giờ được lit (pos_ptr bắt đầu từ 0, mới đi 1 step)
        chk("TC12.0 led[15].brightness=0", dut.led_brightness[15] == 0);
        begin
            int on_cnt = 0;
            repeat(BRIGHTNESS_LEVELS) begin
                @(posedge clk); #1;
                if (leds[15]) on_cnt++;
            end
            // brightness=0: 0>0..4 → all false → off 5/5
            chk("TC12.1 led[15] off 5/5 PWM cycles", on_cnt == 0);
        end

        // ── Summary ─────────────────────────────────────────────
        $display("\n========== %0d passed, %0d failed ==========",
                 pass_cnt, fail_cnt);
        if (fail_cnt == 0) $display("ALL TESTS PASSED");
        $finish;
    end

    // Watchdog — nếu sim treo
    initial begin
        #(TICK_MAX * 200ns * (CW_STEPS*3 + ACW_STEPS*3 + BRIGHTNESS_LEVELS*2 + 20));
        $display("TIMEOUT: simulation hung");
        $finish;
    end

endmodule
