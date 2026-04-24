module counter
    import ring_flasher_pkg::*;
(
    //system
    input logic clk, rst_n,

    //signal
    output logic tick
);
    //ffs
    logic [TICK_WIDTH-1:0] cnt;

    //output
    assign tick = (cnt == TICK_MAX-1) ? 1 : 0;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cnt <= '0;
        else if (tick)
            cnt <= '0;
        else
            cnt <= cnt + 1;
    end
endmodule

module ring_flasher
    import ring_flasher_pkg::*;
(
    //system
    input logic clk, rst_n,
    input logic rep,

    output logic [NUM_LEDS-1:0] leds
);
    //FSM
    state_t state, next_state;

    //tick from counter instance
    logic tick;
    counter u_counter (
        .clk   (clk),
        .rst_n (rst_n),
        .tick  (tick)
    );

    //step counter
    logic [STEP_WIDTH-1:0]  step_cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            step_cnt    <= '0;
        else if (tick) begin
            if (state != next_state)
                step_cnt    <= '0;
            else
                step_cnt    <= step_cnt + 1;
        end
    end

    //position pointer
    logic [POS_WIDTH-1:0]   pos_ptr;

    //next_pos combinational — brightness update
    logic [POS_WIDTH-1:0] next_pos;
    always_comb begin
        case (state)
            FORWARD:  next_pos = (pos_ptr + 1) % NUM_LEDS;
            BACKWARD: next_pos = (pos_ptr - 1 + NUM_LEDS) % NUM_LEDS;
            default:  next_pos = pos_ptr;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pos_ptr <= NUM_LEDS - 1;    //forward tick dau
        else if (tick)
            pos_ptr <= next_pos;
    end

    //brightness registers
    logic [BRIGHT_WIDTH-1:0] led_brightness [NUM_LEDS];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_LEDS; i++)
                led_brightness[i] <= '0;
        end else if (tick) begin
            case (state)
                FORWARD, BACKWARD: begin
                    for (int i = 0; i < NUM_LEDS; i++) begin
                        if (i == int'(next_pos))
                            led_brightness[i] <= BRIGHTNESS_LEVELS;
                        else if (led_brightness[i] > 0)
                            led_brightness[i] <= led_brightness[i] - 1;
                    end
                end

                DECAY: begin
                    for (int i = 0; i < NUM_LEDS; i++) begin
                        if (led_brightness[i] > 0)
                            led_brightness[i] <= led_brightness[i] - 1;
                    end
                end

                default: ; 
            endcase
        end
    end

    //all_off in DECAY -> IDLE trigger
    logic all_off;

    always_comb begin
        all_off = 1'b1;

        for (int i = 0; i < NUM_LEDS; i++)
            if (led_brightness[i] != '0)
                all_off = 1'b0;
    end

    //PWM counter: 0..BRIGHTNESS_LEVELS-1
    logic [BRIGHT_WIDTH-1:0] pwm_cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pwm_cnt <= '0;
        else if (pwm_cnt == BRIGHTNESS_LEVELS - 1)
            pwm_cnt <= '0;
        else
            pwm_cnt <= pwm_cnt + 1;
    end

    //LED output: led[i] on khi brightness[i] > pwm_cnt
    genvar g;
    generate
        for (g = 0; g < NUM_LEDS; g++) begin : gen_led
            assign leds[g] = (led_brightness[g] > pwm_cnt);
        end
    endgenerate

    //next state fsm
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state   <= IDLE;
        else
            state   <= next_state;
    end

    always_comb begin
        next_state  = state;

        case (state)
            IDLE: begin
                if (rep)
                    next_state  = FORWARD;
            end

            FORWARD: begin
                if (tick && step_cnt == CW_STEPS-1)
                    next_state  = BACKWARD;
            end

            BACKWARD: begin
                if (tick && step_cnt == ACW_STEPS-1)
                    next_state  = rep ? FORWARD : DECAY;
            end

            DECAY: begin
                if (tick && all_off)
                    next_state  = IDLE;
            end
        endcase
    end
endmodule
