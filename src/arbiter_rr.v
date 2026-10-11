module tt_um_arbiter_rr (
    input  wire       clk,
    input  wire       rst,
    input  wire [3:0] req,
    output reg  [3:0] grant
);

    // FSM states
    localparam IDLE            = 2'b00;
    localparam CHECK_REQUESTS  = 2'b01;
    localparam GRANT_STATE     = 2'b10;
    localparam WAIT_RELEASE    = 2'b11;

    reg [1:0] state, next_state;
    reg [1:0] pointer;      // whose turn is next (0 to 3)
    reg [1:0] granted_idx;  // who currently holds the grant
    reg [2:0] grant_timer;  // counts how long current grant has been held

    // State register: moves to next_state on every clock edge
    always @(posedge clk or posedge rst) begin
        if (rst)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Pointer register: remembers whose turn is next, rotates after each grant
    always @(posedge clk or posedge rst) begin
        if (rst)
            pointer <= 2'b00;
        else if (state == GRANT_STATE)
            pointer <= granted_idx + 1'b1;  // move to next requester after this grant
    end

    // Next-state logic and grant output
    integer i;
    reg [1:0] found_idx;
    reg       found;

    always @(*) begin
        grant = 4'b0000;
        next_state = state;
        found = 1'b0;
        found_idx = pointer;

        case (state)
            IDLE: begin
                if (req != 4'b0000)
                    next_state = CHECK_REQUESTS;
            end

            CHECK_REQUESTS: begin
                // starting from pointer, find the next requester in rotation
                for (i = 0; i < 4; i = i + 1) begin
                    if (!found && req[(pointer + i) % 4]) begin
                        found_idx = (pointer + i) % 4;
                        found = 1'b1;
                    end
                end
                if (found)
                    next_state = GRANT_STATE;
                else
                    next_state = IDLE;
            end

            GRANT_STATE: begin
                grant[granted_idx] = 1'b1;
                next_state = WAIT_RELEASE;
            end

            WAIT_RELEASE: begin
                grant[granted_idx] = 1'b1;
                if (!req[granted_idx] || grant_timer >= 3'd2)
                    next_state = IDLE;
            end
        endcase
    end

    // Latch which index got granted (for use in WAIT_RELEASE)
    always @(posedge clk or posedge rst) begin
        if (rst)
            granted_idx <= 2'b00;
        else if (state == CHECK_REQUESTS && next_state == GRANT_STATE)
            granted_idx <= found_idx;
    end

    // Grant timer: counts cycles held, forces release after a bounded time
always @(posedge clk or posedge rst) begin
    if (rst)
        grant_timer <= 3'd0;
    else if (state == GRANT_STATE)
        grant_timer <= 3'd0;
    else if (state == WAIT_RELEASE)
        grant_timer <= grant_timer + 1'b1;
end

endmodule