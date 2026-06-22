`timescale 1ns/1ps

module tb_axi_slave;
    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;
    localparam ID_WIDTH   = 4;
    localparam STRB_WIDTH = DATA_WIDTH / 8;

    reg aclk;
    reg aresetn;

    reg  [ID_WIDTH-1:0]    s_axi_awid;
    reg  [ADDR_WIDTH-1:0]  s_axi_awaddr;
    reg  [7:0]             s_axi_awlen;
    reg  [2:0]             s_axi_awsize;
    reg  [1:0]             s_axi_awburst;
    reg                    s_axi_awlock;
    reg  [3:0]             s_axi_awcache;
    reg  [2:0]             s_axi_awprot;
    reg  [3:0]             s_axi_awqos;
    reg                    s_axi_awvalid;
    wire                   s_axi_awready;

    reg  [DATA_WIDTH-1:0]  s_axi_wdata;
    reg  [STRB_WIDTH-1:0]  s_axi_wstrb;
    reg                    s_axi_wlast;
    reg                    s_axi_wvalid;
    wire                   s_axi_wready;

    wire [ID_WIDTH-1:0]    s_axi_bid;
    wire [1:0]             s_axi_bresp;
    wire                   s_axi_bvalid;
    reg                    s_axi_bready;

    reg  [ID_WIDTH-1:0]    s_axi_arid;
    reg  [ADDR_WIDTH-1:0]  s_axi_araddr;
    reg  [7:0]             s_axi_arlen;
    reg  [2:0]             s_axi_arsize;
    reg  [1:0]             s_axi_arburst;
    reg                    s_axi_arlock;
    reg  [3:0]             s_axi_arcache;
    reg  [2:0]             s_axi_arprot;
    reg  [3:0]             s_axi_arqos;
    reg                    s_axi_arvalid;
    wire                   s_axi_arready;

    wire [ID_WIDTH-1:0]    s_axi_rid;
    wire [DATA_WIDTH-1:0]  s_axi_rdata;
    wire [1:0]             s_axi_rresp;
    wire                   s_axi_rlast;
    wire                   s_axi_rvalid;
    reg                    s_axi_rready;

    axi_slave #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .ID_WIDTH(ID_WIDTH),
        .MEM_WORDS(256)
    ) dut (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axi_awid(s_axi_awid),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awlen(s_axi_awlen),
        .s_axi_awsize(s_axi_awsize),
        .s_axi_awburst(s_axi_awburst),
        .s_axi_awlock(s_axi_awlock),
        .s_axi_awcache(s_axi_awcache),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awqos(s_axi_awqos),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wlast(s_axi_wlast),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bid(s_axi_bid),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_arid(s_axi_arid),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arlen(s_axi_arlen),
        .s_axi_arsize(s_axi_arsize),
        .s_axi_arburst(s_axi_arburst),
        .s_axi_arlock(s_axi_arlock),
        .s_axi_arcache(s_axi_arcache),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arqos(s_axi_arqos),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rid(s_axi_rid),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rlast(s_axi_rlast),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready)
    );

    initial begin
        aclk = 1'b0;
        forever #5 aclk = ~aclk;
    end

    task init_inputs;
        begin
            s_axi_awid    = {ID_WIDTH{1'b0}};
            s_axi_awaddr  = {ADDR_WIDTH{1'b0}};
            s_axi_awlen   = 8'd0;
            s_axi_awsize  = 3'd2;
            s_axi_awburst = 2'b01;
            s_axi_awlock  = 1'b0;
            s_axi_awcache = 4'b0011;
            s_axi_awprot  = 3'b000;
            s_axi_awqos   = 4'b0000;
            s_axi_awvalid = 1'b0;
            s_axi_wdata   = {DATA_WIDTH{1'b0}};
            s_axi_wstrb   = {STRB_WIDTH{1'b0}};
            s_axi_wlast   = 1'b0;
            s_axi_wvalid  = 1'b0;
            s_axi_bready  = 1'b0;
            s_axi_arid    = {ID_WIDTH{1'b0}};
            s_axi_araddr  = {ADDR_WIDTH{1'b0}};
            s_axi_arlen   = 8'd0;
            s_axi_arsize  = 3'd2;
            s_axi_arburst = 2'b01;
            s_axi_arlock  = 1'b0;
            s_axi_arcache = 4'b0011;
            s_axi_arprot  = 3'b000;
            s_axi_arqos   = 4'b0000;
            s_axi_arvalid = 1'b0;
            s_axi_rready  = 1'b0;
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

    task drive_aw;
        input [ADDR_WIDTH-1:0] addr;
        input [7:0] len;
        input [2:0] size;
        input [1:0] burst;
        begin
            @(negedge aclk);
            s_axi_awid    = 4'h5;
            s_axi_awaddr  = addr;
            s_axi_awlen   = len;
            s_axi_awsize  = size;
            s_axi_awburst = burst;
            s_axi_awvalid = 1'b1;
            @(posedge aclk);
            while (!s_axi_awready)
                @(posedge aclk);
            @(negedge aclk);
            s_axi_awvalid = 1'b0;
        end
    endtask

    task drive_w;
        input [DATA_WIDTH-1:0] data;
        input [STRB_WIDTH-1:0] strb;
        input last;
        begin
            @(negedge aclk);
            s_axi_wdata  = data;
            s_axi_wstrb  = strb;
            s_axi_wlast  = last;
            s_axi_wvalid = 1'b1;
            @(posedge aclk);
            while (!s_axi_wready)
                @(posedge aclk);
            @(negedge aclk);
            s_axi_wvalid = 1'b0;
            s_axi_wlast  = 1'b0;
        end
    endtask

    task expect_b;
        input [1:0] exp_resp;
        integer guard;
        begin
            guard = 0;
            @(negedge aclk);
            s_axi_bready = 1'b1;
            while (!s_axi_bvalid && guard < 80) begin
                @(posedge aclk);
                guard = guard + 1;
            end
            if (!s_axi_bvalid) begin
                $display("FAIL: BVALID timeout");
                $finish;
            end
            if (s_axi_bresp !== exp_resp || s_axi_bid !== 4'h5) begin
                $display("FAIL: B response mismatch resp=%b id=%h expected=%b", s_axi_bresp, s_axi_bid, exp_resp);
                $finish;
            end
            @(negedge aclk);
            s_axi_bready = 1'b0;
        end
    endtask

    task drive_ar;
        input [ADDR_WIDTH-1:0] addr;
        input [7:0] len;
        input [2:0] size;
        input [1:0] burst;
        begin
            @(negedge aclk);
            s_axi_arid    = 4'h9;
            s_axi_araddr  = addr;
            s_axi_arlen   = len;
            s_axi_arsize  = size;
            s_axi_arburst = burst;
            s_axi_arvalid = 1'b1;
            @(posedge aclk);
            while (!s_axi_arready)
                @(posedge aclk);
            @(negedge aclk);
            s_axi_arvalid = 1'b0;
        end
    endtask

    task expect_r;
        input [DATA_WIDTH-1:0] exp_data;
        input [1:0] exp_resp;
        input exp_last;
        integer guard;
        begin
            guard = 0;
            @(negedge aclk);
            s_axi_rready = 1'b1;
            while (!s_axi_rvalid && guard < 80) begin
                @(posedge aclk);
                guard = guard + 1;
            end
            if (!s_axi_rvalid) begin
                $display("FAIL: RVALID timeout");
                $finish;
            end
            if (s_axi_rdata !== exp_data || s_axi_rresp !== exp_resp || s_axi_rlast !== exp_last || s_axi_rid !== 4'h9) begin
                $display("FAIL: R mismatch data=%h resp=%b last=%0d id=%h", s_axi_rdata, s_axi_rresp, s_axi_rlast, s_axi_rid);
                $display("      expected data=%h resp=%b last=%0d id=9", exp_data, exp_resp, exp_last);
                $finish;
            end
            @(negedge aclk);
            s_axi_rready = 1'b0;
        end
    endtask

    initial begin
        init_inputs();
        apply_reset();

        drive_aw(32'h0000_0010, 8'd1, 3'd2, 2'b01);
        drive_w(32'h1111_2222, 4'b1111, 1'b0);
        drive_w(32'h3333_4444, 4'b1111, 1'b1);
        expect_b(2'b00);

        drive_ar(32'h0000_0010, 8'd1, 3'd2, 2'b01);
        expect_r(32'h1111_2222, 2'b00, 1'b0);
        expect_r(32'h3333_4444, 2'b00, 1'b1);

        drive_aw(32'h0000_0020, 8'd0, 3'd2, 2'b01);
        drive_w(32'hFFFF_FFFF, 4'b1111, 1'b1);
        expect_b(2'b00);
        drive_aw(32'h0000_0020, 8'd0, 3'd2, 2'b01);
        drive_w(32'hAAAA_5555, 4'b0011, 1'b1);
        expect_b(2'b00);
        drive_ar(32'h0000_0020, 8'd0, 3'd2, 2'b01);
        expect_r(32'hFFFF_5555, 2'b00, 1'b1);

        drive_aw(32'h0000_0030, 8'd1, 3'd2, 2'b01);
        drive_w(32'hAAAA_0000, 4'b1111, 1'b0);
        drive_w(32'hBBBB_1111, 4'b1111, 1'b1);
        expect_b(2'b00);
        drive_ar(32'h0000_0034, 8'd1, 3'd2, 2'b10);
        expect_r(32'hBBBB_1111, 2'b00, 1'b0);
        expect_r(32'hAAAA_0000, 2'b00, 1'b1);

        drive_aw(32'h0000_0040, 8'd0, 3'd3, 2'b01);
        drive_w(32'hDEAD_BEEF, 4'b1111, 1'b1);
        expect_b(2'b10);

        drive_ar(32'h0000_0040, 8'd0, 3'd3, 2'b01);
        expect_r(32'h0000_0000, 2'b10, 1'b1);

        $display("PASS: AXI slave full test completed");
        $finish;
    end
endmodule
