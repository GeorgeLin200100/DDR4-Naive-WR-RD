/*
Design Mission:
1. write 20 data to ddr
2. read 0-9 data & read 10-19 data & add them
3. write back 10 results to ddr
4. read 10 results from ddr
5. check validability
*/
`timescale 1ps / 1ps

module example_tb_x #(
  parameter SIMULATION       = "FALSE",   // This parameter must be
                                          // TRUE for simulations and 
                                          // FALSE for implementation.
                                          //
  parameter APP_DATA_WIDTH   = 32,        // Application side data bus width.
                                          // It is 8 times the DQ_WIDTH.
                                          //
  parameter APP_ADDR_WIDTH   = 32,        // Application side Address bus width.
                                          // It is sum of COL, ROW and BANK address
                                          // for DDR3. It is sum of COL, ROW, 
                                          // Bank Group and BANK address for DDR4.
                                          //
  parameter nCK_PER_CLK      = 4,         // Fabric to PHY ratio
                                          //
  parameter MEM_ADDR_ORDER   = "ROW_COLUMN_BANK" // Application address order.
                                                 // "ROW_COLUMN_BANK" is the default
                                                 // address order. Refer to product guide
                                                 // for other address order options.
  )
  (
  // ********* ALL SIGNALS AT THIS INTERFACE ARE ACTIVE HIGH SIGNALS ********/
  input clk,                 // MC UI clock.
                             //
  input rst,                 // MC UI reset signal.
                             //
  input init_calib_complete, // MC calibration done signal coming from MC UI.
                             //
  input app_rdy,             // cmd fifo ready signal coming from MC UI.
                             //
  input app_wdf_rdy,         // write data fifo ready signal coming from MC UI.
                             //
  input app_rd_data_valid,   // read data valid signal coming from MC UI
                             //
  input [APP_DATA_WIDTH-1 : 0]  app_rd_data, // read data bus coming from MC UI
                                             //
  output [2 : 0]                app_cmd,     // command bus to the MC UI
                                             //
  output [APP_ADDR_WIDTH-1 : 0] app_addr,    // address bus to the MC UI
                                             //
  output                        app_en,      // command enable signal to MC UI.
                                             //
  output [(APP_DATA_WIDTH/8)-1 : 0] app_wdf_mask, // write data mask signal which
                                                  // is tied to 0 in this example
                                                  // 
  output [APP_DATA_WIDTH-1: 0]  app_wdf_data, // write data bus to MC UI.
                                              //
  output                        app_wdf_end,  // write burst end signal to MC UI
                                              //
  output                        app_wdf_wren, // write enable signal to MC UI
                                              //
  output                        compare_error,// Memory READ_DATA and example TB
                                              // WRITE_DATA compare error.
  output                        wr_rd_complete                                              
                                              
  );





  //state
  reg [2:0] state;
  reg [2:0] nxt_state;
  localparam IDLE = 3'b000;
  localparam WR0 = 3'b001;
  localparam RD0 = 3'b011;
  localparam RD1 = 3'b010;
  localparam WR1 = 3'b110;
  localparam RD2 = 3'b111;
  localparam WR0_MAX = 20;
  localparam RD0_MAX = 10;
  localparam RD1_MAX = 10;
  localparam WR1_MAX = 10;
  localparam RD2_MAX = 10;


  localparam BEGIN_ADDRESS = 32'h00000000 ;
  localparam MID_ADDRESS = 32'h00000000 + 4'b1000 * RD0_MAX;
  //localparam WB_ADDRESS = 32'h00000000 + 4'b1000 * WR0_MAX;
  localparam WB_ADDRESS = 32'h00000000 + 4'b1000 * 50;
  localparam TCQ  = 100; // To model the clock to out delay
  localparam INT_DATA_WIDTH  = 16 ; 
  localparam RD_CMD = 3'b001;
  localparam WR_CMD = 3'b000;

  reg cmd_en;
  reg init_calib_complete_r;
  reg [4:0] wr_cnt;
  reg [4:0] rd_cnt;
  reg [4:0] rd_cmd_cnt;
  reg wr_rd_complete_r;
  reg wr_en;

  reg [4:0] wr_data_cnt;

  // app_en
  assign app_en = cmd_en & app_rdy;

  //cmd_en_d1
  reg cmd_en_d1;
  always @(posedge clk) begin
    cmd_en_d1 <= cmd_en;
  end

  //app_rdy_d1
  reg app_rdy_d1;
  always @(posedge clk) begin
    app_rdy_d1 <= app_rdy;
  end
  
  
  always @(posedge clk) begin
    init_calib_complete_r <= init_calib_complete;
  end
  
  assign compare_error = 0;
  assign wr_rd_complete = wr_rd_complete_r;
  always @(posedge clk) begin
    if(rst | ~init_calib_complete_r) begin
      wr_rd_complete_r <= 1'b0;
    end else if (state == RD2 & (rd_cnt == RD2_MAX - 1) & app_rd_data_valid) begin
      wr_rd_complete_r <= 1'b1;
    end
  end



  //state
  always @(posedge clk) begin
    state <= nxt_state;
  end
  always @(posedge clk) begin
    if(rst | ~init_calib_complete_r) begin
      nxt_state <= IDLE;
    end else if (state == IDLE & ~wr_rd_complete_r) begin
      nxt_state <= WR0;
    end else if (state == WR0 & (wr_cnt == WR0_MAX - 1) & cmd_en & app_rdy) begin
      nxt_state <= RD0;
    end else if (state == RD0 & (rd_cnt == RD0_MAX - 1) & app_rd_data_valid) begin
      nxt_state <= RD1;
    end else if (state == RD1 & (rd_cnt == RD1_MAX - 1) & app_rd_data_valid) begin
      nxt_state <= WR1;
    end else if (state == WR1 & (wr_cnt == WR1_MAX - 1) & cmd_en & app_rdy) begin
      nxt_state <= RD2;
    end else if (state == RD2 & (rd_cnt == RD2_MAX - 1) & app_rd_data_valid) begin
      nxt_state <= IDLE;
    end
  end

  //app_cmd
  reg [2:0] app_cmd_r;
  assign app_cmd = app_cmd_r;
  always @(posedge clk) begin
    if(rst | ~init_calib_complete_r) begin
      app_cmd_r <= WR_CMD;
    end else if (state == WR0 & (wr_cnt == WR0_MAX - 1) & cmd_en & app_rdy) begin
      app_cmd_r <= RD_CMD;
    end else if (state == RD0 & (rd_cmd_cnt == RD0_MAX - 1) & cmd_en & app_rdy) begin
      app_cmd_r <= RD_CMD;
    end else if (state == RD1 & (rd_cmd_cnt == RD1_MAX - 1) & cmd_en & app_rdy) begin
      app_cmd_r <= WR_CMD;
    end else if (state == WR1 & (wr_cnt == WR1_MAX) & cmd_en & app_rdy) begin
      app_cmd_r <= RD_CMD;
    end else if (state == RD2 & (rd_cmd_cnt == RD2_MAX - 1) & cmd_en & app_rdy) begin
      app_cmd_r <= WR_CMD;
    end
  end

  //app_addr
  reg [APP_ADDR_WIDTH-1 : 0] app_addr_r;
  assign app_addr = app_addr_r;
  always @(posedge clk) begin
    if(rst | ~init_calib_complete_r) begin
      app_addr_r <= BEGIN_ADDRESS;
    end else if (state == WR0 & (wr_cnt < WR0_MAX - 1) & cmd_en & app_rdy) begin
      app_addr_r <= app_addr_r + 4'b1000;
    end else if (state == WR0 & (wr_cnt == WR0_MAX - 1 ) & cmd_en & app_rdy) begin
      app_addr_r <= BEGIN_ADDRESS;
    end else if (state == RD0 & (rd_cmd_cnt < RD0_MAX - 1) & cmd_en & app_rdy) begin
      app_addr_r <= app_addr_r + 4'b1000;
    end else if (state == RD0 & (rd_cmd_cnt == RD0_MAX - 1) & cmd_en & app_rdy) begin
      app_addr_r <= MID_ADDRESS;
    end else if (state == RD1 & (rd_cmd_cnt < RD1_MAX - 1) & cmd_en & app_rdy) begin
      app_addr_r <= app_addr_r + 4'b1000;
    end else if (state == RD1 & (rd_cmd_cnt == RD1_MAX - 1) & cmd_en & app_rdy) begin
      app_addr_r <= WB_ADDRESS;
    end else if (state == WR1 & (wr_cnt < WR1_MAX) & cmd_en & app_rdy) begin
      app_addr_r <= app_addr_r + 4'b1000;
    end else if (state == WR1 & (wr_cnt == WR1_MAX) & cmd_en & app_rdy) begin
      app_addr_r <= WB_ADDRESS;
    end else if (state == RD2 & (rd_cmd_cnt < RD2_MAX - 1) & cmd_en & app_rdy) begin
      app_addr_r <= app_addr_r + 4'b1000;
    end else if (state == RD2 & (rd_cmd_cnt == RD2_MAX - 1) & cmd_en & app_rdy) begin
      app_addr_r <= BEGIN_ADDRESS;
    end
  end

  //data_cache
  reg [APP_DATA_WIDTH-1 : 0] data_cache0 [RD0_MAX-1 : 0];
  reg [APP_DATA_WIDTH-1 : 0] data_cache1 [RD1_MAX-1 : 0];

  //read data to data_cache
  always @(posedge clk) begin
    if (state == RD0 & app_rd_data_valid) begin
      data_cache0[rd_cnt] <= app_rd_data;
    end else if (state == RD1 & app_rd_data_valid) begin
      data_cache1[rd_cnt] <= app_rd_data;
    end
  end

  //add data_cache0 & data_cache1
  wire [APP_DATA_WIDTH-1 : 0] add_data [RD0_MAX-1 : 0];
  genvar i;
  generate
    for(i = 0; i < RD0_MAX; i = i + 1) begin : add_data_gen
      assign add_data[i] = data_cache0[i] + data_cache1[i];
    end
  endgenerate

  //app_wdf_data
  reg [APP_DATA_WIDTH-1 : 0] app_wdf_data_r;
  assign app_wdf_data = app_wdf_data_r;
  always @(posedge clk) begin
    if(rst | ~init_calib_complete_r) begin
      app_wdf_data_r <= 0;
    end else if (state == WR0 & (wr_cnt < WR0_MAX) & wr_en & app_wdf_rdy) begin
      app_wdf_data_r <= app_wdf_data_r + 4'b1000;
    end else if (nxt_state == WR1 & (state == RD1)) begin
      app_wdf_data_r <= add_data[0]; // prepare for WR1
    end else if (state == WR1 & (wr_cnt < WR1_MAX) & wr_en & app_wdf_rdy) begin
      app_wdf_data_r <= add_data[wr_cnt];
      //app_wdf_data_r <= app_wdf_data_r + 4'b1010;
    end
  end
  //app_wdf_mask
  assign app_wdf_mask = 0;
  //app_wdf_end
  assign app_wdf_end = (state == WR0 & wr_en & app_wdf_rdy) | (state == WR1 & wr_en & app_wdf_rdy);
  //app_wdf_wren
  assign app_wdf_wren = (state == WR0 & wr_en & app_wdf_rdy) | (state == WR1 & wr_en & app_wdf_rdy);

  //wr_en
  
  always @(posedge clk) begin
    if(rst | ~init_calib_complete_r) begin
      wr_en <= 1'b0;
    end else if (state == WR0 & (wr_cnt < WR0_MAX - 1) & (wr_data_cnt < WR0_MAX - 1)) begin
      wr_en <= app_wdf_rdy;
    end else if (state == WR0 & (wr_data_cnt == WR0_MAX - 1) & app_wdf_rdy) begin
      wr_en <= 1'b0;
    end else if (state == WR1 & (wr_cnt < WR1_MAX) & (wr_data_cnt < WR1_MAX - 1)) begin
      wr_en <= app_wdf_rdy;
    end else if (state == WR1 & (wr_data_cnt == WR1_MAX) & app_wdf_rdy) begin
      wr_en <= 1'b0;
    end
  end

  //cmd_en
  always @(posedge clk) begin
    if(rst | ~init_calib_complete_r) begin
      cmd_en <= 1'b0;
    end else if (state == WR0 & (wr_cnt < WR0_MAX - 1)) begin
      cmd_en <= app_rdy;
    end else if (state == WR0 & (wr_cnt == WR0_MAX - 1) & cmd_en & app_rdy) begin
      // last WR0 cmd accepeted, WR0 completed
      cmd_en <= 1'b0;
    end else if (state == RD0 & (rd_cmd_cnt < RD0_MAX - 1)) begin
      cmd_en <= app_rdy;
    end else if (state == RD0 & (rd_cmd_cnt == RD0_MAX - 1)) begin
      if (cmd_en & app_rdy) begin
        cmd_en <= 1'b0;
      end else begin
        cmd_en <= cmd_en;
      end
    end else if (state == RD1 & (rd_cmd_cnt < RD1_MAX - 1)) begin
      cmd_en <= app_rdy;
    end else if (state == RD1 & (rd_cmd_cnt == RD1_MAX - 1)) begin
      if (cmd_en & app_rdy) begin
        cmd_en <= 1'b0;
      end else begin
        cmd_en <= cmd_en;
      end
    end else if (state == WR1 & (wr_cnt < WR1_MAX)) begin
      cmd_en <= app_rdy; 
    end else if (state == WR1 & (wr_cnt == WR1_MAX) & cmd_en & app_rdy) begin
      cmd_en <= 1'b0;
    end else if (state == RD2 & (rd_cmd_cnt < RD2_MAX - 1)) begin
      cmd_en <= app_rdy;
    end else if (state == RD2 & (rd_cmd_cnt == RD2_MAX - 1) & cmd_en & app_rdy) begin
      cmd_en <= 1'b0;
    end
  end

  //rd_cmd_cnt
  always @(posedge clk) begin
    if(rst | ~init_calib_complete_r) begin
      rd_cmd_cnt <= 5'b0;
    end else if (state == RD0 & (rd_cmd_cnt < RD0_MAX - 1) & cmd_en & app_rdy) begin
      rd_cmd_cnt <= rd_cmd_cnt + 1;
    end else if (state == RD0 & (rd_cmd_cnt == RD0_MAX - 1) & nxt_state == RD1) begin
      rd_cmd_cnt <= 5'b0;
    end else if (state == RD1 & (rd_cmd_cnt < RD1_MAX - 1) & cmd_en & app_rdy) begin
      rd_cmd_cnt <= rd_cmd_cnt + 1;
    end else if (state == RD1 & (rd_cmd_cnt == RD1_MAX - 1) & nxt_state == WR1) begin
      rd_cmd_cnt <= 5'b0;
    end else if (state == RD2 & (rd_cmd_cnt < RD2_MAX - 1) & cmd_en & app_rdy) begin
      rd_cmd_cnt <= rd_cmd_cnt + 1;
    end else if (state == RD2 & (rd_cmd_cnt == RD2_MAX - 1) & cmd_en & app_rdy) begin
      rd_cmd_cnt <= 5'b0;
    end
  end

  //wr_cnt 
  always @(posedge clk) begin
    if(rst | ~init_calib_complete_r) begin
      wr_cnt <= 5'b0;
    end else if (state == WR0 & (wr_cnt < WR0_MAX - 1) & cmd_en & app_rdy) begin
      wr_cnt <= wr_cnt + 1;
    end else if (state == WR0 & (wr_cnt == WR0_MAX - 1) & (nxt_state != state)) begin
      wr_cnt <= 5'b1;
    end else if (state == WR1 & (wr_cnt < WR1_MAX) & cmd_en & app_rdy) begin
      wr_cnt <= wr_cnt + 1;
    end else if (state == WR1 & (wr_cnt == WR1_MAX - 1) & (nxt_state != state)) begin
      wr_cnt <= 5'b0;
    end
  end

  //rd_cnt
  always @(posedge clk) begin
    if(rst | ~init_calib_complete_r) begin
      rd_cnt <= 5'b0;
    end else if (state == RD0 & app_rd_data_valid & (rd_cnt < RD0_MAX - 1)) begin
      rd_cnt <= rd_cnt + 1;
    end else if (state == RD1 & app_rd_data_valid & (rd_cnt < RD1_MAX - 1)) begin
      rd_cnt <= rd_cnt + 1;
    end else if (state == RD2 & app_rd_data_valid & (rd_cnt < RD2_MAX - 1)) begin
      rd_cnt <= rd_cnt + 1;
    end else begin
      if (nxt_state == RD1 || (nxt_state == WR1) || (nxt_state == IDLE)) begin
        rd_cnt <= 5'b0;
      end else begin
        rd_cnt <= rd_cnt;
      end
    end
  end

    
  //wr_data_cnt

  always @(posedge clk) begin
    if (rst | ~init_calib_complete_r) begin
      wr_data_cnt <= 5'b0;
    end else if (state == WR0 & (wr_data_cnt < WR0_MAX - 1) & wr_en & app_wdf_rdy) begin
      wr_data_cnt <= wr_data_cnt + 1;
    end else if (state == WR0 & (nxt_state != state)) begin
      wr_data_cnt <= 5'b0;
    end else if (state == WR1 & (wr_data_cnt < WR1_MAX - 1) & wr_en & app_wdf_rdy) begin
      wr_data_cnt <= wr_data_cnt + 1;
    end else if (state == WR1 & (nxt_state != state)) begin
      wr_data_cnt <= 5'b0;
    end
  end

endmodule