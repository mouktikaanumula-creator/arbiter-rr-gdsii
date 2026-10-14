import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

    # Phase 1: no requests -> no grants
    for _ in range(5):
        await FallingEdge(dut.clk)
        assert int(dut.uo_out.value) == 0, "grant given with no request"

    # Phase 2: all four requests held high for 60 cycles
    dut.ui_in.value = 0b1111
    events = []      # order in which requesters were granted
    prev = 0
    run = 0
    for _ in range(60):
        await FallingEdge(dut.clk)
        out = int(dut.uo_out.value)
        grant = out & 0b1111
        assert out >> 4 == 0, "upper output bits should be 0"
        assert bin(grant).count("1") <= 1, f"more than one grant: {grant:04b}"
        if grant != 0 and prev == 0:
            events.append(grant.bit_length() - 1)
            run = 1
        elif grant != 0:
            run += 1
            assert run <= 4, "grant held longer than the bounded time"
        prev = grant

    dut._log.info(f"Grant order: {events}")
    assert len(events) >= 8, f"too few grants: {events}"
    assert set(events) == {0, 1, 2, 3}, f"a requester was starved: {events}"
    for a, b in zip(events, events[1:]):
        assert b == (a + 1) % 4, f"not round-robin: {events}"

    # Phase 3: requests removed -> grants stop
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 10)
    await FallingEdge(dut.clk)
    assert int(dut.uo_out.value) == 0, "grant still active after requests dropped"