// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2014-2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * AXI4-Stream register
 */
module taxi_axis_register #
(
    // Register type
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter REG_TYPE = 2
)
(
    input  wire logic  clk,
    input  wire logic  rst,

    /*
     * AXI4-Stream input (sink)
     */
    taxi_axis_if.snk   s_axis,

    /*
     * AXI4-Stream output (source)
     */
    taxi_axis_if.src   m_axis
);

// extract parameters
localparam DATA_W = s_axis.DATA_W;
localparam logic KEEP_EN = s_axis.KEEP_EN && m_axis.KEEP_EN;
localparam KEEP_W = s_axis.KEEP_W;
localparam logic STRB_EN = s_axis.STRB_EN && m_axis.STRB_EN;
localparam logic LAST_EN = s_axis.LAST_EN && m_axis.LAST_EN;
localparam logic ID_EN = s_axis.ID_EN && m_axis.ID_EN;
localparam ID_W = s_axis.ID_W;
localparam logic DEST_EN = s_axis.DEST_EN && m_axis.DEST_EN;
localparam DEST_W = s_axis.DEST_W;
localparam logic USER_EN = s_axis.USER_EN && m_axis.USER_EN;
localparam USER_W = s_axis.USER_W;

// check configuration
if (m_axis.DATA_W != DATA_W)
    $fatal(0, "Error: Interface DATA_W parameter mismatch (instance %m)");

if (KEEP_EN && m_axis.KEEP_W != KEEP_W)
    $fatal(0, "Error: Interface KEEP_W parameter mismatch (instance %m)");
    
    
if (REG_TYPE == 2) begin

    logic [DATA_W-1:0] tdata_reg;
    logic [KEEP_W-1:0] tkeep_reg;
    logic [KEEP_W-1:0] tstrb_reg;
    logic              tvalid_reg;
    logic              tlast_reg;
    logic [ID_W-1:0]   tid_reg;
    logic [DEST_W-1:0] tdest_reg;
    logic [USER_W-1:0] tuser_reg;
    logic              tready_reg;

    logic [DATA_W-1:0] tdata_buf_reg;
    logic [KEEP_W-1:0] tkeep_buf_reg;
    logic [KEEP_W-1:0] tstrb_buf_reg;
    logic              tvalid_buf_reg;
    logic              tlast_buf_reg;
    logic [ID_W-1:0]   tid_buf_reg;
    logic [DEST_W-1:0] tdest_buf_reg;
    logic [USER_W-1:0] tuser_buf_reg;

    logic              tvalid_reg_next;
    logic              tvalid_buf_reg_next;
    logic              tready_reg_next;
    logic              store_input_to_output;
    logic              store_input_to_buf;
    logic              store_buf_to_output;
    logic              tready_reg_nextTEST;
    logic              xorTest;
    assign m_axis.tdata  = tdata_reg;
    assign m_axis.tkeep  = KEEP_EN ? tkeep_reg : '1;
    assign m_axis.tstrb  = STRB_EN ? tstrb_reg : tkeep_reg;
    assign m_axis.tvalid = tvalid_reg;
    assign m_axis.tlast  = LAST_EN ? tlast_reg : 1'b1;
    assign m_axis.tid    = ID_EN   ? tid_reg   : '0;
    assign m_axis.tdest  = DEST_EN ? tdest_reg : '0;
    assign m_axis.tuser  = USER_EN ? tuser_reg : '0;

    assign s_axis.tready = tready_reg;
    
    assign tready_reg_nextTEST = m_axis.tready || (~tvalid_buf_reg && (~tvalid_reg || ~s_axis.tvalid));
    
    always_comb begin       
        store_input_to_output = 1'b0;
        store_input_to_buf = 1'b0;
        store_buf_to_output = 1'b0;
        tvalid_buf_reg_next = tvalid_buf_reg;
        tvalid_reg_next = tvalid_reg;
        
        if (tready_reg) begin
            if (m_axis.tready) begin
                store_input_to_output = s_axis.tvalid;
                tvalid_reg_next = s_axis.tvalid;
            end else if (tvalid_reg) begin
                store_input_to_buf = s_axis.tvalid;
                tvalid_buf_reg_next = s_axis.tvalid;
                //tvalid_reg_next = 1'b0;
            end else begin
                store_input_to_output = s_axis.tvalid;
                tvalid_reg_next = s_axis.tvalid;
            end
        end else if (m_axis.tready) begin
            store_buf_to_output = 1'b1;
            tvalid_buf_reg_next = 1'b0;
            tvalid_reg_next = 1'b1;
        end            
        tready_reg_next = m_axis.tready || ~tvalid_buf_reg_next || ~tvalid_reg_next;
    end
    
    assign xorTest = tready_reg_next ^ tready_reg_nextTEST;
    
    always_ff @(posedge clk) begin
        if (rst) begin         
            tvalid_reg     <= 1'b0;
            tvalid_buf_reg <= 1'b0;
	    tready_reg     <= 1'b0;
        end else if (store_input_to_output) begin 
            tdata_reg <= s_axis.tdata;
	    tkeep_reg <= s_axis.tkeep;
	    tstrb_reg <= s_axis.tstrb;
	    tlast_reg <= s_axis.tlast;
	    tid_reg   <= s_axis.tid;
	    tdest_reg <= s_axis.tdest;
	    tuser_reg <= s_axis.tuser;			
        end else if (store_buf_to_output) begin
            tdata_reg <= tdata_buf_reg;
	    tkeep_reg <= tkeep_buf_reg;
	    tstrb_reg <= tstrb_buf_reg;
	    tlast_reg <= tlast_buf_reg;
	    tid_reg   <= tid_buf_reg;
	    tdest_reg <= tdest_buf_reg;
	    tuser_reg <= tuser_buf_reg;	            
        end
        if (store_input_to_buf) begin
            tdata_buf_reg <= s_axis.tdata;
	    tkeep_buf_reg <= s_axis.tkeep;
	    tstrb_buf_reg <= s_axis.tstrb;
	    tlast_buf_reg <= s_axis.tlast;
	    tid_buf_reg   <= s_axis.tid;
	    tdest_buf_reg <= s_axis.tdest;
	    tuser_buf_reg <= s_axis.tuser;	            
        end
	tvalid_reg     <= tvalid_reg_next;
	tvalid_buf_reg <= tvalid_buf_reg_next;
	tready_reg     <= tready_reg_next;
    end
    
end else if (REG_TYPE == 1) begin

    logic [DATA_W-1:0] tdata_reg;
    logic [KEEP_W-1:0] tkeep_reg;
    logic [KEEP_W-1:0] tstrb_reg;
    logic              tvalid_reg;
    logic              tlast_reg;
    logic [ID_W-1:0]   tid_reg;
    logic [DEST_W-1:0] tdest_reg;
    logic [USER_W-1:0] tuser_reg;
    logic              tready_reg;
    
    logic              tvalid_reg_next;
    logic              tready_reg_next;
    logic              store_input_to_output;
    
    assign m_axis.tdata  = tdata_reg;
    assign m_axis.tkeep  = KEEP_EN ? tkeep_reg : '1;
    assign m_axis.tstrb  = STRB_EN ? tstrb_reg : tkeep_reg;
    assign m_axis.tvalid = tvalid_reg;
    assign m_axis.tlast  = LAST_EN ? tlast_reg : 1'b1;
    assign m_axis.tid    = ID_EN   ? tid_reg   : '0;
    assign m_axis.tdest  = DEST_EN ? tdest_reg : '0;
    assign m_axis.tuser  = USER_EN ? tuser_reg : '0;

    assign s_axis.tready = tready_reg;// || ~tvalid_reg;
    
    always_comb begin       
        tvalid_reg_next = tvalid_reg;
        store_input_to_output = 1'b0;
        if (tready_reg) begin
            tvalid_reg_next = s_axis.tvalid;
            store_input_to_output = s_axis.tvalid;
        end else if (m_axis.tready) begin
            tvalid_reg_next = 1'b0;
        end
        tready_reg_next = ~tvalid_reg_next;
    end
    
    always_ff @(posedge clk) begin
        if (rst) begin         
            tvalid_reg <= 1'b0;
	    tready_reg <= 1'b0;
        end else if (store_input_to_output) begin 
            tdata_reg <= s_axis.tdata;
	    tkeep_reg <= s_axis.tkeep;
	    tstrb_reg <= s_axis.tstrb;
	    tlast_reg <= s_axis.tlast;
	    tid_reg   <= s_axis.tid;
	    tdest_reg <= s_axis.tdest;
	    tuser_reg <= s_axis.tuser;			
        end
	    //if (m_axis.tready) begin //~tvalid_reg || 
	tvalid_reg <= tvalid_reg_next;
	tready_reg <= tready_reg_next;
	    //end
    end
	

end else begin
    // bypass

    assign m_axis.tdata  = s_axis.tdata;
    assign m_axis.tkeep  = KEEP_EN ? s_axis.tkeep : '1;
    assign m_axis.tstrb  = STRB_EN ? s_axis.tstrb : s_axis.tkeep;
    assign m_axis.tvalid = s_axis.tvalid;
    assign m_axis.tlast  = LAST_EN ? s_axis.tlast : 1'b1;
    assign m_axis.tid    = ID_EN   ? s_axis.tid   : '0;
    assign m_axis.tdest  = DEST_EN ? s_axis.tdest : '0;
    assign m_axis.tuser  = USER_EN ? s_axis.tuser : '0;

    assign s_axis.tready = m_axis.tready;
	

end

endmodule

`resetall
