`timescale 1ns/1ps

module tb_axi_master;
    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;
    localparam ID_WIDTH   = 4;
    localparam STRB_WIDTH = DATA_WIDTH / 8;

    reg aclk;
    reg aresetn;

    initial begin
        aclk = 1'b0;
        forever #5 aclk = ~aclk;
    end

    reg                   cmd_valid;
    wire                  cmd_ready;
    reg                   cmd_write;
    reg  [ID_WIDTH-1:0]   cmd_id;
    reg  [ADDR_WIDTH-1:0] cmd_addr;
    reg  [7:0]            cmd_len;
    reg  [2:0]            cmd_size;
    reg  [1:0]            cmd_burst;
    wire                  busy;
    wire                  done;
    wire                  error;
    wire                  timeout;

    reg                   wr_valid;
    wire                  wr_ready;
    reg  [DATA_WIDTH-1:0] wr_data;
    reg  [STRB_WIDTH-1:0] wr_strb;

    wire                  rd_valid;
    reg                   rd_ready;
    wire [DATA_WIDTH-1:0] rd_data;
    wire [1:0]            rd_resp;
    wire                  rd_last;

    wire [ID_WIDTH-1:0]   m_axi_awid;
    wire [ADDR_WIDTH-1:0] m_axi_awaddr;
    wire [7:0]            m_axi_awlen;
    wire [2:0]            m_axi_awsize;
    wire [1:0]            m_axi_awburst;
    wire                  m_axi_awlock;
    wire [3:0]            m_axi_awcache;
    wire [2:0]            m_axi_awprot;
    wire [3:0]            m_axi_awqos;
    wire                  m_axi_awvalid;
    wire                  m_axi_awready;
    wire [DATA_WIDTH-1:0] m_axi_wdata;
    wire [STRB_WIDTH-1:0] m_axi_wstrb;
    wire                  m_axi_wlast;
    wire                  m_axi_wvalid;
    wire                  m_axi_wready;
    wire [ID_WIDTH-1:0]   m_axi_bid;
    wire [1:0]            m_axi_bresp;
    wire                  m_axi_bvalid;
    wire                  m_axi_bready;
    wire [ID_WIDTH-1:0]   m_axi_arid;
    wire [ADDR_WIDTH-1:0] m_axi_araddr;
    wire [7:0]            m_axi_arlen;
    wire [2:0]            m_axi_arsize;
    wire [1:0]            m_axi_arburst;
    wire                  m_axi_arlock;
    wire [3:0]            m_axi_arcache;
    wire [2:0]            m_axi_arprot;
    wire [3:0]            m_axi_arqos;
    wire                  m_axi_arvalid;
    wire                  m_axi_arready;
    wire [ID_WIDTH-1:0]   m_axi_rid;
    wire [DATA_WIDTH-1:0] m_axi_rdata;
    wire [1:0]            m_axi_rresp;
    wire                  m_axi_rlast;
    wire                  m_axi_rvalid;
    wire                  m_axi_rready;

    reg inject_bresp_error;
    reg inject_rresp_error;
    reg stall_all_channels;

    axi_master #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .ID_WIDTH(ID_WIDTH),
        .TIMEOUT_CYCLES(32)
    ) dut (
        .aclk(aclk),
        .aresetn(aresetn),
        .cmd_valid(cmd_valid),
        .cmd_ready(cmd_ready),
        .cmd_write(cmd_write),
        .cmd_id(cmd_id),
        .cmd_addr(cmd_addr),
        .cmd_len(cmd_len),
        .cmd_size(cmd_size),
        .cmd_burst(cmd_burst),
        .busy(busy),
        .done(done),
        .error(error),
        .timeout(timeout),
        .wr_valid(wr_valid),
        .wr_ready(wr_ready),
        .wr_data(wr_data),
        .wr_strb(wr_strb),
        .rd_valid(rd_valid),
        .rd_ready(rd_ready),
        .rd_data(rd_data),
        .rd_resp(rd_resp),
        .rd_last(rd_last),
        .m_axi_awid(m_axi_awid),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awlock(m_axi_awlock),
        .m_axi_awcache(m_axi_awcache),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awqos(m_axi_awqos),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready),
        .m_axi_bid(m_axi_bid),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_arid(m_axi_arid),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arlock(m_axi_arlock),
        .m_axi_arcache(m_axi_arcache),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arqos(m_axi_arqos),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        .m_axi_rid(m_axi_rid),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready)
    );

    axi_slave_mem_model #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .ID_WIDTH(ID_WIDTH)
    ) slave (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axi_awid(m_axi_awid),
        .s_axi_awaddr(m_axi_awaddr),
        .s_axi_awlen(m_axi_awlen),
        .s_axi_awsize(m_axi_awsize),
        .s_axi_awburst(m_axi_awburst),
        .s_axi_awvalid(m_axi_awvalid),
        .s_axi_awready(m_axi_awready),
        .s_axi_wdata(m_axi_wdata),
        .s_axi_wstrb(m_axi_wstrb),
        .s_axi_wlast(m_axi_wlast),
        .s_axi_wvalid(m_axi_wvalid),
        .s_axi_wready(m_axi_wready),
        .s_axi_bid(m_axi_bid),
        .s_axi_bresp(m_axi_bresp),
        .s_axi_bvalid(m_axi_bvalid),
        .s_axi_bready(m_axi_bready),
        .s_axi_arid(m_axi_arid),
        .s_axi_araddr(m_axi_araddr),
        .s_axi_arlen(m_axi_arlen),
        .s_axi_arsize(m_axi_arsize),
        .s_axi_arburst(m_axi_arburst),
        .s_axi_arvalid(m_axi_arvalid),
        .s_axi_arready(m_axi_arready),
        .s_axi_rid(m_axi_rid),
        .s_axi_rdata(m_axi_rdata),
        .s_axi_rresp(m_axi_rresp),
        .s_axi_rlast(m_axi_rlast),
        .s_axi_rvalid(m_axi_rvalid),
        .s_axi_rready(m_axi_rready),
        .inject_bresp_error(inject_bresp_error),
        .inject_rresp_error(inject_rresp_error),
        .stall_all_channels(stall_all_channels)
    );

    task init_inputs;
        begin
            cmd_valid         = 1'b0;
            cmd_write         = 1'b0;
            cmd_id            = {ID_WIDTH{1'b0}};
            cmd_addr          = {ADDR_WIDTH{1'b0}};
            cmd_len           = 8'd0;
            cmd_size          = 3'd2;
            cmd_burst         = 2'b01;
            wr_valid          = 1'b0;
            wr_data           = {DATA_WIDTH{1'b0}};
            wr_strb           = {STRB_WIDTH{1'b0}};
            rd_ready          = 1'b1;
            inject_bresp_error = 1'b0;
            inject_rresp_error = 1'b0;
            stall_all_channels = 1'b0;
        end
    endtask

    task apply_reset;
        begin
            aresetn = 1'b0;
            repeat (5) @(posedge aclk);
            aresetn = 1'b1;
            repeat (2) @(posedge aclk);
        end
    endtask

    task send_cmd;
        input write;
        input [ADDR_WIDTH-1:0] addr;
        input [7:0] len;
        begin
            while (!cmd_ready) @(posedge aclk);
            @(negedge aclk);
            cmd_write = write;
            cmd_addr  = addr;
            cmd_len   = len;
            cmd_size  = 3'd2;
            cmd_burst = 2'b01;
            cmd_id    = 4'h3;
            cmd_valid = 1'b1;
            @(posedge aclk);
            while (!cmd_ready)
                @(posedge aclk);
            @(negedge aclk);
            cmd_valid = 1'b0;
        end
    endtask

    task push_write_beat;
        input [DATA_WIDTH-1:0] data;
        begin
            @(negedge aclk);
            wr_data  = data;
            wr_strb  = {STRB_WIDTH{1'b1}};
            wr_valid = 1'b1;
            @(posedge aclk);
            while (!wr_ready)
                @(posedge aclk);
            @(negedge aclk);
            wr_valid = 1'b0;
        end
    endtask

    task wait_done_expect;
        input exp_error;
        input exp_timeout;
        integer guard;
        begin
            guard = 0;
            while (!done && guard < 300) begin
                @(posedge aclk);
                guard = guard + 1;
            end
            if (!done) begin
                $display("FAIL: done did not assert");
                $finish;
            end
            if (error !== exp_error || timeout !== exp_timeout) begin
                $display("FAIL: expected error=%0d timeout=%0d, got error=%0d timeout=%0d",
                         exp_error, exp_timeout, error, timeout);
                $finish;
            end
            @(posedge aclk);
        end
    endtask

    task expect_read_beat;
        input [DATA_WIDTH-1:0] exp_data;
        input exp_last;
        integer guard;
        begin
            guard = 0;
            while (!rd_valid && guard < 200) begin
                @(posedge aclk);
                guard = guard + 1;
            end
            if (!rd_valid) begin
                $display("FAIL: rd_valid did not assert");
                $finish;
            end
            if (rd_data !== exp_data || rd_last !== exp_last) begin
                $display("FAIL: read mismatch data=%h last=%0d expected data=%h last=%0d",
                         rd_data, rd_last, exp_data, exp_last);
                $finish;
            end
            @(posedge aclk);
        end
    endtask

    initial begin
        init_inputs();
        apply_reset();

        send_cmd(1'b1, 32'h0000_0010, 8'd1);
        push_write_beat(32'h1234_5678);
        push_write_beat(32'hCAFE_BABE);
        wait_done_expect(1'b0, 1'b0);

        send_cmd(1'b0, 32'h0000_0010, 8'd1);
        expect_read_beat(32'h1234_5678, 1'b0);
        expect_read_beat(32'hCAFE_BABE, 1'b1);
        wait_done_expect(1'b0, 1'b0);

        inject_bresp_error = 1'b1;
        send_cmd(1'b1, 32'h0000_0020, 8'd0);
        push_write_beat(32'h0BAD_BEEF);
        wait_done_expect(1'b1, 1'b0);
        inject_bresp_error = 1'b0;

        inject_rresp_error = 1'b1;
        send_cmd(1'b0, 32'h0000_0010, 8'd0);
        expect_read_beat(32'h1234_5678, 1'b1);
        wait_done_expect(1'b1, 1'b0);
        inject_rresp_error = 1'b0;

        stall_all_channels = 1'b1;
        send_cmd(1'b0, 32'h0000_0030, 8'd0);
        wait_done_expect(1'b1, 1'b1);
        if (busy !== 1'b0) begin
            $display("FAIL: busy did not clear after timeout");
            $finish;
        end
        stall_all_channels = 1'b0;

        $display("PASS: AXI master full test completed");
        $finish;
    end
endmodule
