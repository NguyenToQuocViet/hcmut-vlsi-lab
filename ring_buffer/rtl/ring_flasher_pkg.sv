`timescale 1ns/1ps

package ring_flasher_pkg;
    localparam  NUM_LEDS            = 16;
    localparam  CLK_FREQ            = 5_000_000;
    localparam  STEP_INTERVAL_MS    = 500;
    localparam  CW_STEPS            = 12;
    localparam  ACW_STEPS           = 8;
    localparam  BRIGHTNESS_LEVELS   = 5;
    localparam  STEP_WIDTH          = 4;

`ifdef SIMULATION
    localparam  TICK_MAX    = 20;               // 20 clocks/tick để sim nhanh
`else
    localparam  TICK_MAX    = CLK_FREQ * STEP_INTERVAL_MS / 1000;
`endif
    localparam  TICK_WIDTH      = $clog2(TICK_MAX);
    localparam  BRIGHT_WIDTH    = $clog2(BRIGHTNESS_LEVELS + 1);
    localparam  POS_WIDTH       = $clog2(NUM_LEDS);

    // FSM state — đặt ở package để testbench dùng được
    typedef enum logic [1:0] {
        IDLE     = 2'b00,
        FORWARD  = 2'b01,
        BACKWARD = 2'b10,
        DECAY    = 2'b11
    } state_t;
endpackage
